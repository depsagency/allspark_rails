class DigitalOceanService
  require 'net/http'
  require 'json'
  
  API_BASE = 'https://api.digitalocean.com/v2'
  
  def initialize(api_token = ENV['DIGITALOCEAN_API_TOKEN'])
    @api_token = api_token
    raise "DigitalOcean API token not configured" unless @api_token
  end
  
  def list_droplets(tag_name: nil)
    url = "#{API_BASE}/droplets"
    url += "?tag_name=#{tag_name}" if tag_name
    
    make_request(:get, url)
  end
  
  def get_droplet(droplet_id)
    make_request(:get, "#{API_BASE}/droplets/#{droplet_id}")
  end
  
  def list_load_balancers
    make_request(:get, "#{API_BASE}/load_balancers")
  end
  
  def get_load_balancer(lb_id)
    make_request(:get, "#{API_BASE}/load_balancers/#{lb_id}")
  end
  
  def get_swarm_cluster_info(cluster_name = 'allspark-swarm')
    # Get manager node
    managers = list_droplets(tag_name: 'manager')
    manager = managers['droplets']&.find { |d| d['name'].include?(cluster_name) }
    
    # Get worker nodes
    workers = list_droplets(tag_name: 'worker')
    worker_nodes = workers['droplets']&.select { |d| d['name'].include?(cluster_name) }
    
    # Get load balancer
    lbs = list_load_balancers
    load_balancer = lbs['load_balancers']&.find { |lb| lb['name'].include?(cluster_name) }
    
    {
      manager: manager,
      workers: worker_nodes,
      load_balancer: load_balancer,
      cluster_healthy: manager && !worker_nodes.empty? && load_balancer
    }
  end
  
  def add_domain_to_load_balancer(domain, lb_id = nil)
    # Get load balancer ID if not provided
    unless lb_id
      cluster_info = get_swarm_cluster_info
      lb_id = cluster_info[:load_balancer]&.dig('id')
      raise "Load balancer not found" unless lb_id
    end
    
    # Get current forwarding rules
    lb = get_load_balancer(lb_id)
    current_rules = lb['load_balancer']['forwarding_rules']
    
    # Add new rule for the domain (if using DO's certificate management)
    # This would require additional configuration
    
    { success: true, load_balancer_id: lb_id }
  end
  
  def get_cluster_connection_info
    cluster_info = get_swarm_cluster_info
    
    raise "Cluster not found or unhealthy" unless cluster_info[:cluster_healthy]
    
    {
      manager_ip: cluster_info[:manager]['networks']['v4'].find { |n| n['type'] == 'public' }&.dig('ip_address'),
      manager_private_ip: cluster_info[:manager]['networks']['v4'].find { |n| n['type'] == 'private' }&.dig('ip_address'),
      load_balancer_ip: cluster_info[:load_balancer]['ip'],
      worker_count: cluster_info[:workers].size,
      cluster_name: cluster_info[:manager]['name'].split('-')[0...-1].join('-')
    }
  end
  
  private
  
  def make_request(method, url, body = nil)
    uri = URI(url)
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = case method
    when :get
      Net::HTTP::Get.new(uri)
    when :post
      Net::HTTP::Post.new(uri)
    when :put
      Net::HTTP::Put.new(uri)
    when :delete
      Net::HTTP::Delete.new(uri)
    end
    
    request['Authorization'] = "Bearer #{@api_token}"
    request['Content-Type'] = 'application/json'
    
    request.body = body.to_json if body
    
    response = http.request(request)
    
    unless response.is_a?(Net::HTTPSuccess)
      raise "DigitalOcean API error: #{response.code} - #{response.body}"
    end
    
    JSON.parse(response.body)
  rescue => e
    Rails.logger.error "DigitalOcean API error: #{e.message}"
    raise
  end
end