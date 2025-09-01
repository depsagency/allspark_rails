class McpServer < ApplicationRecord
  belongs_to :user, optional: true
  has_many :mcp_audit_logs, dependent: :destroy

  validates :name, presence: true
  validates :endpoint, presence: true
  validates :protocol_version, presence: true
  
  # Ensure unique names within scope
  validates :name, uniqueness: { scope: :user_id }

  enum :status, { inactive: 0, active: 1, error: 2 }
  enum :auth_type, { no_auth: 0, api_key: 1, oauth: 2, bearer_token: 3 }
  enum :transport_type, { http: 0, websocket: 1, sse: 2 }

  # JSON serialization for config and credentials
  serialize :config, coder: JSON
  serialize :credentials, coder: JSON

  # Scopes for access
  scope :available_to_user, ->(user) { 
    where(user: [nil, user]) 
  }
  scope :system_wide, -> { where(user_id: nil) }
  scope :by_status, ->(status) { where(status: status) }

  # Callbacks
  before_validation :set_defaults
  after_save :clear_tools_cache
  after_update :trigger_discovery_on_activation

  def available_tools
    # Use registry for better caching and conflict resolution
    registry = McpToolRegistry.instance
    tools = registry.get_server_tools(id)
    
    # If no tools in registry, trigger discovery
    if tools.empty? && active?
      trigger_tool_discovery
    end
    
    tools
  end

  def trigger_tool_discovery(force: false)
    McpToolDiscoveryJob.perform_later(id, force: force)
  end

  def discover_tools_now
    McpToolDiscoveryJob.perform_now(id, force: true)
  end

  def test_connection
    client = McpClient.new(self)
    result = client.test_connection
    
    if result
      update(status: :active) unless active?
      { success: true, message: "Connection successful" }
    else
      update(status: :error)
      { success: false, error: "Connection test failed" }
    end
  rescue => e
    update(status: :error)
    { success: false, error: e.message }
  end

  def server_info
    client = McpClient.new(self)
    client.get_server_info
  rescue => e
    Rails.logger.error "Failed to get server info for MCP server #{id}: #{e.message}"
    nil
  end

  def clear_tools_cache
    Rails.cache.delete("mcp_server_#{id}_tools")
    
    # Also clear from registry
    if id.present?
      McpToolRegistry.instance.clear_server_tools(id)
    end
  end

  private

  def trigger_discovery_on_activation
    # Trigger discovery when server becomes active
    if saved_change_to_status? && active?
      trigger_tool_discovery(force: true)
    end
  end

  def set_defaults
    self.protocol_version ||= '1.0'
    self.status ||= :inactive
    self.auth_type ||= :no_auth
    self.config ||= {}
    self.credentials ||= {}
  end

  def fetch_tools_from_server
    return [] unless active? || inactive?
    
    client = McpClient.new(self)
    tools = client.discover_tools
    
    # Update status to active if successful and was inactive
    update(status: :active) if inactive? && tools.any?
    
    tools
  rescue => e
    Rails.logger.error "Failed to fetch tools from MCP server #{id}: #{e.message}"
    update(status: :error)
    []
  end
end