class CreateMcpProcessTracking < ActiveRecord::Migration[8.0]
  def change
    # Table to track active MCP processes
    create_table :mcp_processes, id: :uuid do |t|
      t.uuid :process_uuid, null: false
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.uuid :mcp_configuration_id, null: false
      t.integer :process_id
      t.string :status, null: false, default: 'starting'
      t.datetime :started_at, null: false
      t.datetime :last_activity_at, null: false
      t.integer :restart_count, default: 0
      t.json :capabilities
      t.json :tools
      t.text :error_message
      
      t.timestamps
      
      t.index [:user_id, :mcp_configuration_id], name: 'idx_mcp_processes_on_user_and_config'
      t.index :process_uuid, unique: true
      t.index :status
      t.index :last_activity_at
    end
    
    # Table to track tool executions for analytics
    create_table :mcp_tool_executions, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.uuid :mcp_configuration_id, null: false
      t.string :tool_name, null: false
      t.json :arguments
      t.json :result
      t.boolean :success, null: false, default: false
      t.integer :execution_time_ms
      t.string :error_code
      t.text :error_message
      
      t.timestamps
      
      t.index [:user_id, :mcp_configuration_id, :tool_name], name: 'idx_mcp_tool_exec_on_user_config_tool'
      t.index :tool_name
      t.index :success
      t.index :created_at
    end
    
    # Add index for faster lookups
    add_index :mcp_tool_executions, [:mcp_configuration_id, :created_at], name: 'idx_mcp_tool_exec_on_config_and_time'
  end
end