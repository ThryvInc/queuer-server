class AddPointsToSprintProjects < ActiveRecord::Migration[4.2]
  def change
    add_column :sprint_projects, :points, :integer
    add_column :sprint_projects, :remaining_points, :integer
  end
end
