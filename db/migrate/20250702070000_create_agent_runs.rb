class CreateAgentRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_runs, id: :uuid do |t|
      t.references :assistant, type: :uuid, foreign_key: true, null: false
      t.references :user, type: :uuid, foreign_key: true
      t.string :run_id, null: false
      t.integer :status, default: 0, null: false
      t.datetime :started_at
      t.datetime :completed_at
      t.json :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :agent_runs, :run_id, unique: true
    add_index :agent_runs, :status
    add_index :agent_runs, :created_at
  end
end