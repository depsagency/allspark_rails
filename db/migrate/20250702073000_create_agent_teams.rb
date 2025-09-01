class CreateAgentTeams < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_teams, id: :uuid do |t|
      t.references :user, type: :uuid, foreign_key: true, null: false
      t.string :name, null: false
      t.text :purpose
      t.json :configuration, default: {}
      t.boolean :active, default: true
      
      t.timestamps
    end
    
    create_table :agent_teams_assistants, id: false do |t|
      t.references :agent_team, type: :uuid, foreign_key: true, null: false
      t.references :assistant, type: :uuid, foreign_key: true, null: false
    end
    
    add_index :agent_teams, :name
    add_index :agent_teams, :active
    add_index :agent_teams_assistants, [:agent_team_id, :assistant_id], unique: true, name: 'idx_teams_assistants'
  end
end