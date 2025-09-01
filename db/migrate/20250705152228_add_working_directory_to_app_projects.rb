class AddWorkingDirectoryToAppProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :app_projects, :working_directory, :string
  end
end
