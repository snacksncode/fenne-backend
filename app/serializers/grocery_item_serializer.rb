class GroceryItemSerializer
  def self.render(grocery_item, recipes_by_id: {})
    product = grocery_item.product
    recipes_by_id = grocery_item.recipes.index_by(&:id) if recipes_by_id.empty?
    recipe_ids = grocery_item.normalized_recipe_ids
    recipes = recipe_ids.map do |id|
      recipe = recipes_by_id[id]
      { id: id.to_s, name: recipe ? recipe.name : "Unknown recipe" }
    end

    {
      id: grocery_item.id.to_s,
      product: product ? ProductSerializer.render(product) : nil,
      name: product&.name || grocery_item.name,
      quantity: grocery_item.purchase_quantity.to_f,
      purchase: grocery_item.purchase_suggestion,
      quantity_overridden: grocery_item.quantity_overridden,
      aisle: product&.aisle || grocery_item.aisle,
      unit: product&.unit || grocery_item.unit,
      status: grocery_item.status,
      source: grocery_item.source,
      recipes: recipes
    }
  end

  def self.render_many(grocery_items)
    items = grocery_items.to_a
    recipes_by_id = GroceryItem.recipes_by_id_for(items)
    items.map { |grocery_item| render(grocery_item, recipes_by_id: recipes_by_id) }
  end
end
