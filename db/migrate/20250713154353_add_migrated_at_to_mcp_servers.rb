class AddMigratedAtToMcpServers < ActiveRecord::Migration[8.0]
  def change
    add_column :mcp_servers, :migrated_at, :datetime
  end
end
