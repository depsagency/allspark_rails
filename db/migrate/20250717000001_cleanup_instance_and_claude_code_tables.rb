class CleanupInstanceAndClaudeCodeTables < ActiveRecord::Migration[8.0]
  def up
    # Remove foreign keys first
    remove_foreign_key :app_projects, :instances if foreign_key_exists?(:app_projects, :instances)
    remove_foreign_key :mcp_servers, :instances if foreign_key_exists?(:mcp_servers, :instances)
    
    # Remove instance_id columns
    remove_column :app_projects, :instance_id, :uuid if column_exists?(:app_projects, :instance_id)
    remove_column :mcp_servers, :instance_id, :uuid if column_exists?(:mcp_servers, :instance_id)
    
    # Use CASCADE to drop all dependent objects
    execute "DROP TABLE IF EXISTS claude_code_file_operations CASCADE"
    execute "DROP TABLE IF EXISTS claude_code_message_reads CASCADE"
    execute "DROP TABLE IF EXISTS claude_code_pending_changes CASCADE"
    execute "DROP TABLE IF EXISTS claude_code_commands CASCADE"
    execute "DROP TABLE IF EXISTS claude_code_messages CASCADE"
    execute "DROP TABLE IF EXISTS claude_code_sessions CASCADE"
    
    execute "DROP TABLE IF EXISTS slack_messages CASCADE"
    execute "DROP TABLE IF EXISTS slack_integrations CASCADE"
    execute "DROP TABLE IF EXISTS deployment_logs CASCADE"
    execute "DROP TABLE IF EXISTS instance_logs CASCADE"
    execute "DROP TABLE IF EXISTS instance_users CASCADE"
    execute "DROP TABLE IF EXISTS instances CASCADE"
  end
  
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end