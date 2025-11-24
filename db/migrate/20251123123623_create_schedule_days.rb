class CreateScheduleDays < ActiveRecord::Migration[8.0]
  def change
    create_table :schedule_days do |t|
      t.references :family, null: false, foreign_key: true
      t.date :date, null: false
      t.references :breakfast_recipe, foreign_key: {to_table: :recipes}
      t.references :lunch_recipe, foreign_key: {to_table: :recipes}
      t.references :dinner_recipe, foreign_key: {to_table: :recipes}
      t.boolean :is_shopping_day, default: false

      t.timestamps

      t.index [:family_id, :date], unique: true
    end
  end
end
