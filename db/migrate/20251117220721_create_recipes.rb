class CreateRecipes < ActiveRecord::Migration[8.0]
  def change
    create_table :recipes do |t|
      t.references :family, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :meal_types_bitmask, null: false

      t.timestamps
    end
  end
end
