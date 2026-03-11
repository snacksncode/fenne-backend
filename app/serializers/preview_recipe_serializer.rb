class PreviewRecipeSerializer
  def self.render(recipe, schedule_items:, unit_preference:)
    {
      id: recipe.id.to_s,
      name: recipe.name,
      meal_type: schedule_items.first.meal_type,
      amount: schedule_items.size,
      ingredients: recipe.ingredients.map { |i| PreviewIngredientSerializer.render(i, unit_preference: unit_preference) }
    }
  end

  def self.render_many(grouped, unit_preference:)
    grouped.map { |recipe, items| render(recipe, schedule_items: items, unit_preference: unit_preference) }
  end
end
