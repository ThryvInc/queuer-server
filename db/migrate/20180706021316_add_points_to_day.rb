class AddPointsToDay < ActiveRecord::Migration[4.2]
  def change
    add_column :days, :points, :integer, default: 0
    add_column :days, :finished_points, :integer, default: 0
  end
end
