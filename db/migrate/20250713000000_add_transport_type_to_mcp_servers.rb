class AddTransportTypeToMcpServers < ActiveRecord::Migration[7.0]
  def change
    add_column :mcp_servers, :transport_type, :integer, default: 0, null: false
    add_index :mcp_servers, :transport_type
  end
end