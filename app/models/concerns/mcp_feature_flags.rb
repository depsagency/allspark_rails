# app/models/concerns/mcp_feature_flags.rb
module McpFeatureFlags
  extend ActiveSupport::Concern
  
  # Check if the new MCP configuration system is enabled
  def mcp_configurations_enabled?
    # Check user-specific flag first
    return true if feature_enabled?(:mcp_configuration_enabled)
    
    # Check percentage rollout
    return true if in_rollout_percentage?(:mcp_configuration_enabled)
    
    # Check if user has already migrated (always enable for migrated users)
    return true if mcp_configurations.exists?
    
    # Default to old system
    false
  end
  
  # Check if user should see migration prompts
  def should_show_mcp_migration?
    # Only show if new system is enabled but user hasn't migrated
    mcp_configurations_enabled? && legacy_mcp_servers.exists?
  end
  
  # Get legacy MCP servers for migration
  def legacy_mcp_servers
    if self.is_a?(User)
      McpServer.where(user: self, migrated_at: nil)
    else
      McpServer.none
    end
  end
  
  private
  
  def feature_enabled?(flag_name)
    # Simple implementation - replace with your feature flag service
    if defined?(Flipper)
      Flipper.enabled?(flag_name, self)
    elsif defined?(FeatureFlag)
      FeatureFlag.enabled?(flag_name, user: self)
    else
      # Fallback to environment variable
      ENV["FEATURE_#{flag_name.to_s.upcase}"] == "true"
    end
  end
  
  def in_rollout_percentage?(flag_name)
    # Simple percentage rollout based on user ID
    percentage = ENV.fetch("FEATURE_#{flag_name.to_s.upcase}_PERCENTAGE", "0").to_i
    return false if percentage == 0
    return true if percentage >= 100
    
    # Use consistent hashing for stable rollout
    hash = Digest::MD5.hexdigest("#{flag_name}:#{id}")
    hash_value = hash[0..7].to_i(16)
    max_value = 0xFFFFFFFF
    
    (hash_value.to_f / max_value * 100) < percentage
  end
end