class AddProjectTypeAndDesignTasksToAppProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :app_projects, :project_type, :string, default: 'project_kickoff'
    add_column :app_projects, :design_tasks, :jsonb, default: {}
    
    # Add index for project_type for faster queries
    add_index :app_projects, :project_type
  end
end
