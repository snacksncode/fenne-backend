class AlignIngredientsWithProductBackedSchema < ActiveRecord::Migration[8.0]
  def change
    return unless table_exists?(:ingredients)

    if column_exists?(:ingredients, :display_name) && !column_exists?(:ingredients, :name_override)
      rename_column :ingredients, :display_name, :name_override
    end

    remove_column :ingredients, :name if column_exists?(:ingredients, :name)
    remove_column :ingredients, :aisle if column_exists?(:ingredients, :aisle)

    change_column_null :ingredients, :product_id, false if column_exists?(:ingredients, :product_id)
  end
end
