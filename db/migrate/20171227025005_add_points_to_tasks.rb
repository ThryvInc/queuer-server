class AddPointsToTasks < ActiveRecord::Migration[4.2]
  def change
    add_column :tasks, :points, :integer, default: 1
  end
end
