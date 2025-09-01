class DockerHealthService
  def self.check_instance(instance_slug)
    result = {
      status: 'unknown',
      containers: {},
      checked_at: Time.current,
      errors: []
    }

    begin
      # Check if the instance directory exists
      instance_dir = Rails.root.join('allspark-projects', instance_slug)
      unless Dir.exist?(instance_dir)
        result[:status] = 'not_found'
        result[:errors] << "Instance directory not found: #{instance_dir}"
        return result
      end

      # Check Docker containers for this instance
      # For now, we'll check the main containers since instances share the same Docker setup
      containers_to_check = %w[web sidekiq db redis]
      
      containers_to_check.each do |service|
        container_name = "allspark-#{service}-1"
        status = check_container_status(container_name)
        result[:containers][service] = status
      end

      # Determine overall status
      all_running = result[:containers].values.all? { |c| c[:status] == 'running' }
      any_running = result[:containers].values.any? { |c| c[:status] == 'running' }
      
      result[:status] = if all_running
                          'healthy'
                        elsif any_running
                          'partial'
                        else
                          'down'
                        end

    rescue => e
      result[:status] = 'error'
      result[:errors] << "Health check failed: #{e.message}"
    end

    result
  end

  private

  def self.check_container_status(container_name)
    output = `docker ps --filter "name=#{container_name}" --format "{{.Status}}" 2>&1`.strip
    
    if output.empty?
      { status: 'not_running', message: 'Container not found' }
    elsif output.include?('Up')
      uptime = output.match(/Up (.+?)(\s+\(|$)/)[1] rescue 'unknown'
      { status: 'running', uptime: uptime, message: output }
    else
      { status: 'error', message: output }
    end
  rescue => e
    { status: 'error', message: e.message }
  end
end