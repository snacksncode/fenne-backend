class RecipeSerializer
  def self.render(recipe)
    {
      id: recipe.id.to_s,
      name: recipe.name,
      meal_types: recipe.meal_types,
      liked: recipe.liked,
      time_in_minutes: recipe.time_in_minutes,
      ingredients: recipe.ingredients.map do |ingredient|
        {
          id: ingredient.id.to_s,
          name: ingredient.name,
          unit: ingredient.unit,
          aisle: ingredient.aisle,
          quantity: ingredient.quantity.to_f
        }
      end
    }
  end

  def self.render_many(recipes)
    recipes.map { |r| render(r) }
  end
end
