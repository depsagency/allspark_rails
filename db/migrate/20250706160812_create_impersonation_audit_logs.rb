class CreateImpersonationAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :impersonation_audit_logs, id: :uuid do |t|
      t.references :impersonator, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.references :impersonated_user, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.text :reason
      t.string :ip_address
      t.string :user_agent
      t.string :session_id
      t.datetime :started_at
      t.datetime :ended_at
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :impersonation_audit_logs, [:impersonator_id, :started_at]
    add_index :impersonation_audit_logs, [:impersonated_user_id, :started_at]
    add_index :impersonation_audit_logs, :action
    add_index :impersonation_audit_logs, :session_id
  end
end
