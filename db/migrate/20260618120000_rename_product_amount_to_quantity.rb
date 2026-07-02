class RenameProductAmountToQuantity < ActiveRecord::Migration[8.0]
  def change
    return unless table_exists?(:products)
    return if column_exists?(:products, :quantity)
    return unless column_exists?(:products, :amount)

    rename_column :products, :amount, :quantity
  end
end
