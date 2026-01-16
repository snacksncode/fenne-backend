class CreateFoodItems < ActiveRecord::Migration[8.0]
  def change
    create_table :food_items do |t|
      t.string :name, null: false
      t.integer :aisle, null: false
      t.references :family, null: true, foreign_key: true

      t.timestamps
    end
  end
end
