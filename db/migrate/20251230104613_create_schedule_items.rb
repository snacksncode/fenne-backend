class CreateScheduleItems < ActiveRecord::Migration[8.0]
  def change
    create_table :schedule_items do |t|
      t.references :schedule_day, null: false, foreign_key: true
      t.integer :kind, null: false
      t.integer :meal_type, null: false

      t.references :recipe, foreign_key: true, null: true
      t.string :dining_out_name, null: true
      t.timestamps
    end

    # prevent multiple meals assigned to the same day, with the same meal type
    add_index :schedule_items, [:schedule_day_id, :meal_type], unique: true
  end
end
