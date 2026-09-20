class AddPurchasePlanning < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :pack_sizes, :json, default: [], null: false
    add_column :grocery_items, :needed_quantity, :decimal, precision: 15, scale: 6
    add_column :grocery_items, :quantity_overridden, :boolean, default: true, null: false
  end
end
