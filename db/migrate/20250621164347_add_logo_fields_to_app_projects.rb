class AddLogoFieldsToAppProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :app_projects, :generated_logo_url, :string
    add_column :app_projects, :logo_prompt, :text
    add_column :app_projects, :logo_generation_metadata, :jsonb, default: {}

    add_index :app_projects, :generated_logo_url
  end
end
