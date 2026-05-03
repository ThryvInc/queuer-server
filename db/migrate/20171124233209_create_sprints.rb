class CreateSprints < ActiveRecord::Migration[4.2]
  def change
    create_table :sprints do |t|
      t.datetime :start_date
      t.datetime :end_date
      t.string :name
      t.integer :user_id

      t.timestamps null: false
    end
  end
end
