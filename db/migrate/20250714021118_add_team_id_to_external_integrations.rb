class AddTeamIdToExternalIntegrations < ActiveRecord::Migration[8.0]
  def change
    add_column :external_integrations, :team_id, :string
  end
end
