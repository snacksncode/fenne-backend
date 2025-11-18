class CreateIngredients < ActiveRecord::Migration[8.0]
  def change
    create_table :ingredients do |t|
      t.references :recipe, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :unit, null: false
      t.decimal :quantity, null: false

      t.timestamps
    end
  end
end
