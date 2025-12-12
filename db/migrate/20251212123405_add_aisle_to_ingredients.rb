class AddAisleToIngredients < ActiveRecord::Migration[8.0]
  def change
    add_column :ingredients, :aisle, :integer, null: false, default: 14
  end
end
