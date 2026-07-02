class SnapshotRecipeNameOnConsumptionLogs < ActiveRecord::Migration[8.0]
  class ConsumptionLog < ActiveRecord::Base; end
  class Recipe < ActiveRecord::Base; end

  def up
    add_column :consumption_logs, :recipe_name, :string

    ConsumptionLog.find_each do |log|
      recipe_name = Recipe.find_by(id: log.recipe_id)&.name || "Unknown recipe"
      log.update_columns(recipe_name: recipe_name, updated_at: Time.current)
    end

    change_column_null :consumption_logs, :recipe_name, false
    remove_reference :consumption_logs, :recipe, foreign_key: true
  end

  def down
    add_reference :consumption_logs, :recipe, foreign_key: true
    remove_column :consumption_logs, :recipe_name
  end
end
