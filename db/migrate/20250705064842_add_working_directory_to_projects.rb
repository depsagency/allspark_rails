class AddWorkingDirectoryToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :working_directory, :string
    add_index :projects, :working_directory
  end
end
