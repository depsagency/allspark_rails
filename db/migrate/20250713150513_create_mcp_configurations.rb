class CreateMcpConfigurations < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_configurations, id: :uuid do |t|
      t.string :owner_type, null: false
      t.uuid :owner_id, null: false
      t.string :name, null: false
      t.text :server_config # Will be encrypted
      t.integer :server_type, default: 0, null: false
      t.boolean :enabled, default: true, null: false
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :mcp_configurations, [:owner_type, :owner_id]
    add_index :mcp_configurations, :enabled
    add_index :mcp_configurations, :server_type
  end
end
