class AddNotesToRecipe < ActiveRecord::Migration[8.0]
  def change
    add_column :recipes, :notes, :string, null: false, default: ""
  end
end
