class DockerCommandService
  class Result
    attr_reader :output, :error_message, :exit_status
    
    def initialize(output: nil, error_message: nil, exit_status: 0)
      @output = output
      @error_message = error_message
      @exit_status = exit_status
    end
    
    def success?
      exit_status == 0 && error_message.nil?
    end
  end
  
  class << self
    def start_instance(slug)
      script_path = Rails.root.join('bin', 'start-instance.sh')
      execute_script(script_path, slug)
    end
    
    def stop_instance(slug)
      script_path = Rails.root.join('bin', 'stop-instance.sh')
      execute_script(script_path, slug)
    end
    
    def restart_instance(slug)
      script_path = Rails.root.join('bin', 'restart-instance.sh')
      execute_script(script_path, slug)
    end
    
    def get_logs(slug, lines: 100, service: 'web')
      instance_dir = Rails.root.join('instances', slug, 'allspark')
      
      return "Instance directory not found" unless Dir.exist?(instance_dir)
      
      output = nil
      Dir.chdir(instance_dir) do
        cmd = "docker-compose logs --tail=#{lines} #{service}"
        output = `#{cmd} 2>&1`
      end
      
      output || "No logs available"
    end
    
    private
    
    def execute_script(script_path, slug)
      return Result.new(error_message: "Script not found: #{script_path}") unless File.exist?(script_path)
      
      output = []
      error = nil
      exit_status = nil
      
      Open3.popen2e("bash #{script_path} #{slug}") do |stdin, stdout_and_stderr, wait_thr|
        stdout_and_stderr.each_line do |line|
          output << line.chomp
        end
        
        exit_status = wait_thr.value.exitstatus
      end
      
      if exit_status != 0
        error = output.last(5).join("\n")
      end
      
      Result.new(
        output: output.join("\n"),
        error_message: error,
        exit_status: exit_status
      )
    rescue => e
      Result.new(
        error_message: e.message,
        exit_status: 1
      )
    end
  end
end