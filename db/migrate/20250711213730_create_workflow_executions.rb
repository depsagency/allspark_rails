class CreateWorkflowExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :workflow_executions, id: :uuid do |t|
      t.uuid :workflow_id, null: false
      t.uuid :started_by, null: false
      t.string :status, default: 'pending'
      t.datetime :started_at
      t.datetime :completed_at
      t.jsonb :execution_data, default: {}
      
      t.timestamps
    end
    
    add_index :workflow_executions, :workflow_id
    add_foreign_key :workflow_executions, :workflows
    add_foreign_key :workflow_executions, :users, column: :started_by
  end
end
