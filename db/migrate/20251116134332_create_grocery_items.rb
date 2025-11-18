class CreateGroceryItems < ActiveRecord::Migration[8.0]
  def change
    create_table :grocery_items do |t|
      t.references :family, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :quantity, null: false
      t.integer :aisle, null: false
      t.integer :unit, null: false

      t.timestamps
    end
  end
end
