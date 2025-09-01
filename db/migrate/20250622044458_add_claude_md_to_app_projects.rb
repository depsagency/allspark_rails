class AddClaudeMdToAppProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :app_projects, :generated_claude_md, :text
    add_column :app_projects, :claude_md_metadata, :jsonb
  end
end
