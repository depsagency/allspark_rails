class CreateWorkflows < ActiveRecord::Migration[8.0]
  def change
    create_table :workflows, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.uuid :team_id, null: false
      t.uuid :user_id, null: false
      t.text :mermaid_definition
      t.jsonb :flow_definition, default: {}
      t.string :status, default: 'draft'
      t.integer :version, default: 1
      
      t.timestamps
    end
    
    add_index :workflows, :team_id
    add_foreign_key :workflows, :agent_teams, column: :team_id
    add_foreign_key :workflows, :users
  end
end
