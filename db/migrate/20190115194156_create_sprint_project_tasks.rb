class CreateSprintProjectTasks < ActiveRecord::Migration[4.2]
  def change
    create_table :sprint_project_tasks do |t|
      t.integer :sprint_id
      t.integer :project_id
      t.integer :task_id

      t.timestamps null: false
    end
  end
end
