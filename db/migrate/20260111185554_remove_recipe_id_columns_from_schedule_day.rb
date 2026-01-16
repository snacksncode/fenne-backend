class RemoveRecipeIdColumnsFromScheduleDay < ActiveRecord::Migration[8.0]
  def change
    remove_column :schedule_days, :breakfast_recipe_id, :integer
    remove_column :schedule_days, :lunch_recipe_id, :integer
    remove_column :schedule_days, :dinner_recipe_id, :integer
  end
end
