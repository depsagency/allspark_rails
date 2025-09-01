class CreateAgentTeamExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_team_executions, id: :uuid do |t|
      t.references :agent_team, type: :uuid, foreign_key: true, null: false
      t.text :task, null: false
      t.integer :status, default: 0, null: false
      t.datetime :started_at
      t.datetime :completed_at
      t.json :result_data
      t.text :error_message
      
      t.timestamps
    end
    
    add_index :agent_team_executions, :status
    add_index :agent_team_executions, :created_at
  end
end