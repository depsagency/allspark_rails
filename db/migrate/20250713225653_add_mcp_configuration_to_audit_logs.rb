class AddMcpConfigurationToAuditLogs < ActiveRecord::Migration[8.0]
  def change
    add_reference :mcp_audit_logs, :mcp_configuration, null: true, foreign_key: true, type: :uuid
  end
end
