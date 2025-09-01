class CreateAppProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :app_projects, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :status, default: 'draft'

      # User responses to 10 configuration questions
      t.text :vision_response
      t.text :users_response
      t.text :journeys_response
      t.text :features_response
      t.text :technical_response
      t.text :integrations_response
      t.text :success_response
      t.text :competition_response
      t.text :design_response
      t.text :challenges_response

      # AI-generated outputs
      t.text :generated_prd
      t.text :generated_tasks
      t.text :generated_claude_prompt
      t.jsonb :generation_metadata, default: {}

      t.references :user, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end

    add_index :app_projects, :slug, unique: true
    add_index :app_projects, :status
  end
end
