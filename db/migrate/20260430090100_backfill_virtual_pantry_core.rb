class BackfillVirtualPantryCore < ActiveRecord::Migration[8.0]
  class FoodItem < ActiveRecord::Base; end
  class ProductSuggestion < ActiveRecord::Base; end
  class Recipe < ActiveRecord::Base; end
  class Ingredient < ActiveRecord::Base; end
  class Product < ActiveRecord::Base; end
  class GroceryItem < ActiveRecord::Base; end

  def up
    backfill_product_suggestions
    backfill_ingredient_products
    backfill_grocery_products
    merge_duplicate_active_grocery_rows
    add_index :grocery_items,
      [:family_id, :product_id],
      unique: true,
      where: "product_id IS NOT NULL AND status IN (0, 1)",
      name: "idx_grocery_items_one_active_product"
  end

  def down
    remove_index :grocery_items, name: "idx_grocery_items_one_active_product", if_exists: true
    ProductSuggestion.delete_all
    Product.delete_all
  end

  private

  def backfill_product_suggestions
    FoodItem.where(family_id: nil).find_each do |food_item|
      normalized = food_item.name.to_s.strip
      next if normalized.blank?
      next if ProductSuggestion.where("LOWER(TRIM(name)) = ?", normalized.downcase).exists?

      ProductSuggestion.create!(name: normalized, aisle: food_item.aisle)
    end
  end

  def backfill_ingredient_products
    Ingredient.find_each do |ingredient|
      recipe = Recipe.find_by(id: ingredient.recipe_id)
      next unless recipe

      product = find_or_create_product(
        family_id: recipe.family_id,
        name: ingredient.name,
        aisle: ingredient.aisle
      )

      ingredient.update_columns(
        product_id: product.id,
        name_override: nil,
        unit: ingredient.unit || 12,
        updated_at: Time.current
      )
    end

    change_column_null :ingredients, :product_id, false
    remove_column :ingredients, :name
    remove_column :ingredients, :aisle
  end

  def backfill_grocery_products
    GroceryItem.find_each do |grocery_item|
      grocery_item.update_columns(
        product_id: nil,
        source: 1,
        recipe_ids: [],
        updated_at: Time.current
      )
    end
  end

  def find_or_create_product(family_id:, name:, aisle:)
    normalized = name.to_s.strip
    existing = Product.where(family_id: family_id)
      .where("LOWER(TRIM(name)) = ?", normalized.downcase)
      .first
    return existing if existing

    Product.create!(
      family_id: family_id,
      name: normalized,
      aisle: aisle || 14,
      unit: 12,
      conversions: {}
    )
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def merge_duplicate_active_grocery_rows
    rows = GroceryItem
      .where.not(product_id: nil)
      .where(status: [0, 1])
      .order(:id)
      .group_by { |item| [item.family_id, item.product_id] }

    rows.each_value do |items|
      next if items.one?

      keeper = items.first
      duplicates = items.drop(1)
      total_quantity = items.sum { |item| BigDecimal(item.quantity.to_s) }
      recipe_ids = items.flat_map { |item| Array(item.recipe_ids) }.map(&:to_i).uniq

      keeper.update_columns(
        quantity: total_quantity,
        recipe_ids: recipe_ids,
        updated_at: Time.current
      )
      GroceryItem.where(id: duplicates.map(&:id)).delete_all
    end
  end
end
