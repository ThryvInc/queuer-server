class AddPointsToProjects < ActiveRecord::Migration[4.2]
  def change
    add_column :projects, :points, :integer, default: 0
    add_column :projects, :remaining_points, :integer, default: 0
  end
end
