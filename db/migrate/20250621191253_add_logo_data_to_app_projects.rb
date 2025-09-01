class AddLogoDataToAppProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :app_projects, :logo_data, :text
  end
end
