class AddStatusToGroceryItems < ActiveRecord::Migration[8.0]
  def change
    add_column :grocery_items, :status, :integer, null: false, default: 0
  end
end
