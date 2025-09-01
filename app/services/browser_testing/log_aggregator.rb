# frozen_string_literal: true

module BrowserTesting
  class LogAggregator
    attr_reader :logs

    def initialize
      @logs = {}
    end

    def collect_logs_for_request(start_time, end_time = nil)
      end_time ||= Time.current.iso8601
      
      @logs = {
        rails: collect_rails_logs(start_time, end_time),
        docker: collect_docker_logs(start_time),
        timestamp_range: {
          start: start_time,
          end: end_time
        }
      }

      # Add system info
      @logs[:system] = collect_system_info

      @logs
    end

    def collect_recent_logs(minutes = 5)
      start_time = (Time.current - minutes.minutes).iso8601
      collect_logs_for_request(start_time)
    end

    private

    def collect_rails_logs(start_time, end_time)
      logs = []
      log_file = Rails.root.join("log", "#{Rails.env}.log")
      
      return logs unless File.exist?(log_file)

      begin
        # Read the log file backwards for efficiency
        File.open(log_file, "r") do |file|
          file.seek(0, IO::SEEK_END)
          buffer = ""
          chunk_size = 4096
          
          while file.pos > 0 && logs.size < 100
            # Read chunk
            read_size = [chunk_size, file.pos].min
            file.seek(-read_size, IO::SEEK_CUR)
            chunk = file.read(read_size)
            file.seek(-read_size, IO::SEEK_CUR)
            
            # Process lines
            buffer = chunk + buffer
            lines = buffer.split("\n")
            
            # Keep incomplete line for next iteration
            buffer = lines.shift || ""
            
            # Process complete lines
            lines.reverse.each do |line|
              if timestamp = extract_timestamp(line)
                if timestamp >= start_time && timestamp <= end_time
                  logs.unshift(line)
                elsif timestamp < start_time
                  return logs # Stop if we've gone too far back
                end
              end
            end
          end
        end
      rescue => e
        Rails.logger.error "[LogAggregator] Error reading Rails logs: #{e.message}"
      end

      logs
    end

    def collect_docker_logs(since)
      docker_logs = {}
      
      # Get logs from each service
      %w[web sidekiq db redis].each do |service|
        docker_logs[service] = get_docker_service_logs(service, since)
      end

      docker_logs
    end

    def get_docker_service_logs(service, since)
      logs = []
      
      begin
        # Try to get logs from Docker Compose
        container_name = detect_container_name(service)
        return logs unless container_name

        # Get logs with timestamps
        cmd = if File.exist?("/.dockerenv")
          # We're inside a container, use docker directly
          "docker logs --since='#{since}' --timestamps #{container_name} 2>&1"
        else
          # We're on the host, use docker-compose
          "docker-compose logs --since='#{since}' --timestamps #{service} 2>&1"
        end

        output = `#{cmd}`
        
        if $?.success?
          logs = output.split("\n").map do |line|
            # Clean up docker-compose prefixes
            line.sub(/^[^\|]+\|\s*/, '')
          end
        end
      rescue => e
        Rails.logger.warn "[LogAggregator] Could not get #{service} logs: #{e.message}"
      end

      logs
    end

    def collect_system_info
      {
        memory: get_memory_info,
        disk: get_disk_info,
        containers: get_container_status
      }
    end

    def get_memory_info
      if File.exist?("/proc/meminfo")
        meminfo = File.read("/proc/meminfo")
        total = meminfo.match(/MemTotal:\s+(\d+)/)&.captures&.first&.to_i || 0
        available = meminfo.match(/MemAvailable:\s+(\d+)/)&.captures&.first&.to_i || 0
        
        {
          total_mb: total / 1024,
          available_mb: available / 1024,
          used_percent: ((total - available) * 100.0 / total).round(2)
        }
      else
        {}
      end
    rescue
      {}
    end

    def get_disk_info
      output = `df -h /app 2>/dev/null`.split("\n").last
      if output
        parts = output.split(/\s+/)
        {
          total: parts[1],
          used: parts[2],
          available: parts[3],
          used_percent: parts[4]
        }
      else
        {}
      end
    rescue
      {}
    end

    def get_container_status
      if File.exist?("/.dockerenv")
        # Inside container - get our own status
        {
          running_in_container: true,
          container_id: File.read("/proc/self/cgroup").match(/docker\/(\w+)/)&.captures&.first
        }
      else
        # On host - get all container statuses
        output = `docker-compose ps --format json 2>/dev/null`
        if $?.success? && output.present?
          JSON.parse(output)
        else
          {}
        end
      end
    rescue
      {}
    end

    def detect_container_name(service)
      # Try to detect the container name
      project_name = File.basename(Rails.root)
      
      # Common patterns
      patterns = [
        "#{project_name}-#{service}-1",
        "#{project_name}_#{service}_1",
        "allspark-#{service}-1",
        "allspark_#{service}_1"
      ]

      # Check which pattern matches an existing container
      patterns.find do |pattern|
        `docker ps --format '{{.Names}}' 2>/dev/null`.split("\n").include?(pattern)
      end
    end

    def extract_timestamp(log_line)
      # Try to extract timestamp from log line
      # Rails default format: "I, [2024-01-15T10:30:45.123456 #1234]"
      if match = log_line.match(/\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+)/)
        match[1]
      elsif match = log_line.match(/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})/)
        match[1]
      else
        nil
      end
    end
  end
end