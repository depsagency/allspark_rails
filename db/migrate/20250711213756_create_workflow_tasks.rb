class CreateWorkflowTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :workflow_tasks, id: :uuid do |t|
      t.uuid :workflow_execution_id, null: false
      t.string :node_id, null: false
      t.uuid :assistant_id
      t.string :title
      t.text :instructions
      t.string :status, default: 'pending'
      t.datetime :started_at
      t.datetime :completed_at
      t.jsonb :result_data, default: {}
      
      t.timestamps
    end
    
    add_index :workflow_tasks, :workflow_execution_id
    add_index :workflow_tasks, :assistant_id
    add_foreign_key :workflow_tasks, :workflow_executions
    add_foreign_key :workflow_tasks, :assistants
  end
end
