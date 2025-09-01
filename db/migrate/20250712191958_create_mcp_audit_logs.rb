class CreateMcpAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_audit_logs, id: :uuid do |t|
      t.references :user, type: :uuid, foreign_key: true, null: false
      t.references :mcp_server, type: :uuid, foreign_key: true, null: false
      t.references :assistant, type: :uuid, foreign_key: true, null: false
      t.string :tool_name, null: false
      t.text :request_data
      t.text :response_data
      t.datetime :executed_at, null: false
      t.integer :status # success, failure, timeout
      t.integer :response_time_ms

      t.timestamps

      t.index :executed_at
      t.index [:mcp_server_id, :executed_at]
      t.index [:user_id, :executed_at]
    end
  end
end
