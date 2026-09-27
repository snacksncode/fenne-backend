class RemoveShoppingDays < ActiveRecord::Migration[8.0]
  def change
    remove_column :schedule_days, :is_shopping_day, :boolean, default: false
  end
end
