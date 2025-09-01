class CreateMcpServers < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_servers, id: :uuid do |t|
      t.string :name, null: false
      t.string :endpoint, null: false
      t.string :protocol_version, default: '1.0'
      t.integer :auth_type, default: 0, null: false
      t.text :config
      t.text :credentials
      t.integer :status, default: 0, null: false
      t.references :user, type: :uuid, foreign_key: true, null: true
      t.references :instance, type: :uuid, foreign_key: true, null: true
      t.timestamps

      t.index [:name, :instance_id], unique: true, where: "instance_id IS NOT NULL"
      t.index [:name, :user_id], unique: true, where: "user_id IS NOT NULL"
      t.index :status
    end
  end
end
