class AddMarketingPageFieldsToAppProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :app_projects, :generated_marketing_page_id, :uuid
    add_column :app_projects, :marketing_page_prompt, :text
    add_column :app_projects, :marketing_page_metadata, :jsonb, default: {}

    add_foreign_key :app_projects, :pages, column: :generated_marketing_page_id
    add_index :app_projects, :generated_marketing_page_id
  end
end
