class CreateDays < ActiveRecord::Migration[4.2]
  def change
    create_table :days do |t|
      t.datetime :date
      t.integer :sprint_id

      t.timestamps null: false
    end
  end
end
