class AddProjectToTaskAndUserToProject < ActiveRecord::Migration[4.2]
  def change
    add_column :projects, :user_id, :integer
    add_column :tasks, :project_id, :integer
  end
end
