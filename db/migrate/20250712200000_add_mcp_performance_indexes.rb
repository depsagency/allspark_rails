class AddMcpPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Indexes for MCP servers
    add_index :mcp_servers, [:status, :created_at], name: 'index_mcp_servers_on_status_and_created_at'
    add_index :mcp_servers, [:user_id, :status], name: 'index_mcp_servers_on_user_and_status'
    add_index :mcp_servers, [:instance_id, :status], name: 'index_mcp_servers_on_instance_and_status'
    add_index :mcp_servers, [:auth_type, :status], name: 'index_mcp_servers_on_auth_type_and_status'
    
    # Indexes for MCP audit logs
    add_index :mcp_audit_logs, [:mcp_server_id, :executed_at], name: 'index_mcp_audit_logs_on_server_and_executed_at'
    add_index :mcp_audit_logs, [:user_id, :executed_at], name: 'index_mcp_audit_logs_on_user_and_executed_at'
    add_index :mcp_audit_logs, [:status, :executed_at], name: 'index_mcp_audit_logs_on_status_and_executed_at'
    add_index :mcp_audit_logs, [:tool_name, :executed_at], name: 'index_mcp_audit_logs_on_tool_and_executed_at'
    add_index :mcp_audit_logs, [:executed_at, :response_time_ms], name: 'index_mcp_audit_logs_on_executed_at_and_response_time'
    
    # Composite indexes for common queries
    add_index :mcp_audit_logs, [:mcp_server_id, :status, :executed_at], 
              name: 'index_mcp_audit_logs_on_server_status_executed'
    add_index :mcp_audit_logs, [:user_id, :status, :executed_at], 
              name: 'index_mcp_audit_logs_on_user_status_executed'
    
    # Partial indexes for active servers (PostgreSQL specific)
    if connection.adapter_name == 'PostgreSQL'
      execute <<-SQL
        CREATE INDEX index_mcp_servers_active_on_updated_at 
        ON mcp_servers (updated_at) 
        WHERE status = 0;
      SQL
      
      execute <<-SQL
        CREATE INDEX index_mcp_audit_logs_recent_successful 
        ON mcp_audit_logs (executed_at, response_time_ms) 
        WHERE status = 0;
      SQL
    end
    
    # Add database-level constraints for data integrity
    add_check_constraint :mcp_audit_logs, "response_time_ms >= 0", name: "positive_response_time"
    add_check_constraint :mcp_servers, "protocol_version IN ('1.0', '1.1', '2.0')", name: "valid_protocol_version"
  end
  
  def down
    # Remove indexes
    remove_index :mcp_servers, name: 'index_mcp_servers_on_status_and_created_at'
    remove_index :mcp_servers, name: 'index_mcp_servers_on_user_and_status'
    remove_index :mcp_servers, name: 'index_mcp_servers_on_instance_and_status'
    remove_index :mcp_servers, name: 'index_mcp_servers_on_auth_type_and_status'
    
    remove_index :mcp_audit_logs, name: 'index_mcp_audit_logs_on_server_and_executed_at'
    remove_index :mcp_audit_logs, name: 'index_mcp_audit_logs_on_user_and_executed_at'
    remove_index :mcp_audit_logs, name: 'index_mcp_audit_logs_on_status_and_executed_at'
    remove_index :mcp_audit_logs, name: 'index_mcp_audit_logs_on_tool_and_executed_at'
    remove_index :mcp_audit_logs, name: 'index_mcp_audit_logs_on_executed_at_and_response_time'
    remove_index :mcp_audit_logs, name: 'index_mcp_audit_logs_on_server_status_executed'
    remove_index :mcp_audit_logs, name: 'index_mcp_audit_logs_on_user_status_executed'
    
    # Remove PostgreSQL specific indexes
    if connection.adapter_name == 'PostgreSQL'
      execute "DROP INDEX IF EXISTS index_mcp_servers_active_on_updated_at;"
      execute "DROP INDEX IF EXISTS index_mcp_audit_logs_recent_successful;"
    end
    
    # Remove constraints
    remove_check_constraint :mcp_audit_logs, name: "positive_response_time"
    remove_check_constraint :mcp_servers, name: "valid_protocol_version"
  end
end