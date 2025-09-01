class AddPolymorphicOwnerToMcpServers < ActiveRecord::Migration[8.0]
  def change
    add_column :mcp_servers, :owner_type, :string
    add_column :mcp_servers, :owner_id, :uuid
    
    add_index :mcp_servers, [:owner_type, :owner_id]
    
    # Migrate existing user_id to polymorphic owner
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE mcp_servers 
          SET owner_type = 'User', owner_id = user_id::uuid 
          WHERE user_id IS NOT NULL
        SQL
      end
    end
  end
end
