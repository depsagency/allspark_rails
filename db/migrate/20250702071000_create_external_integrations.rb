class CreateExternalIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :external_integrations, id: :uuid do |t|
      t.references :user, type: :uuid, foreign_key: true, null: false
      t.integer :service, null: false
      t.text :access_token, null: false
      t.text :refresh_token
      t.datetime :expires_at
      t.json :metadata, default: {}
      t.boolean :active, default: true
      
      t.timestamps
    end
    
    add_index :external_integrations, [:user_id, :service], unique: true
    add_index :external_integrations, :service
    add_index :external_integrations, :active
  end
end