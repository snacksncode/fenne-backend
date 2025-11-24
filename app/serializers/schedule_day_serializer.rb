class ScheduleDaySerializer
  def self.render(day)
    {
      date: day.date.to_s,
      breakfast: day.breakfast_recipe ? RecipeSerializer.render(day.breakfast_recipe) : nil,
      lunch: day.lunch_recipe ? RecipeSerializer.render(day.lunch_recipe) : nil,
      dinner: day.dinner_recipe ? RecipeSerializer.render(day.dinner_recipe) : nil,
      is_shopping_day: day.is_shopping_day
    }
  end

  def self.render_many(days)
    days.map { |day| render(day) }
  end
end
