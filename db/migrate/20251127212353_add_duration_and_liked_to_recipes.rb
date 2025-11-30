class AddDurationAndLikedToRecipes < ActiveRecord::Migration[8.0]
  def change
    add_column :recipes, :liked, :boolean, null: false, default: false
    add_column :recipes, :time_in_minutes, :integer, null: false, default: 0
  end
end
