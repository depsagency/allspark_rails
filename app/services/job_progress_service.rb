class JobProgressService
  attr_reader :job_id, :key
  
  def initialize(job_id)
    @job_id = job_id
    @key = "job_progress:#{job_id}"
  end
  
  def start(total_steps: 100, metadata: {})
    data = {
      job_id: job_id,
      status: 'running',
      current_step: 0,
      total_steps: total_steps,
      progress_percentage: 0,
      started_at: Time.current,
      metadata: metadata,
      messages: []
    }
    
    Redis.current.setex(key, 1.hour.to_i, data.to_json)
  end
  
  def update(current_step: nil, message: nil, metadata: {})
    data = get_progress
    return unless data
    
    if current_step
      data['current_step'] = current_step
      data['progress_percentage'] = calculate_percentage(current_step, data['total_steps'])
    end
    
    if message
      data['messages'] << {
        message: message,
        timestamp: Time.current,
        step: data['current_step']
      }
    end
    
    data['metadata'].merge!(metadata) if metadata.any?
    data['updated_at'] = Time.current
    
    Redis.current.setex(key, 1.hour.to_i, data.to_json)
  end
  
  def complete(message: nil)
    data = get_progress
    return unless data
    
    data['status'] = 'completed'
    data['progress_percentage'] = 100
    data['completed_at'] = Time.current
    data['messages'] << { message: message, timestamp: Time.current } if message
    
    Redis.current.setex(key, 1.hour.to_i, data.to_json)
  end
  
  def fail(error_message)
    data = get_progress
    return unless data
    
    data['status'] = 'failed'
    data['error'] = error_message
    data['failed_at'] = Time.current
    
    Redis.current.setex(key, 1.hour.to_i, data.to_json)
  end
  
  def get_progress
    data = Redis.current.get(key)
    return nil unless data
    
    JSON.parse(data).with_indifferent_access
  rescue JSON::ParserError
    nil
  end
  
  def self.track_job(job_id, total_steps: 100)
    service = new(job_id)
    service.start(total_steps: total_steps)
    
    begin
      yield(service)
      service.complete
    rescue => e
      service.fail(e.message)
      raise
    end
  end
  
  private
  
  def calculate_percentage(current, total)
    return 0 if total.zero?
    ((current.to_f / total) * 100).round(2)
  end
end