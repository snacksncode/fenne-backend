class PreviewRecipeSerializer
  def self.render(recipe, schedule_items:)
    {
      id: recipe.id.to_s,
      name: recipe.name,
      meal_type: schedule_items.first.meal_type,
      amount: schedule_items.size,
      ingredients: recipe.ingredients.map { |ingredient| PreviewIngredientSerializer.render(ingredient) }
    }
  end

  def self.render_many(grouped)
    grouped.map { |recipe, items| render(recipe, schedule_items: items) }
  end
end
