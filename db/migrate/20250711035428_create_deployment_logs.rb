class CreateDeploymentLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :deployment_logs, id: :uuid do |t|
      t.references :instance, null: false, foreign_key: true, type: :uuid
      t.string :deployment_type
      t.string :status
      t.text :message
      t.jsonb :metadata
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
    
    add_index :deployment_logs, :status
    add_index :deployment_logs, :started_at
  end
end
