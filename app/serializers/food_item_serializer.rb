class FoodItemSerializer
  def self.render(food_item)
    {
      id: food_item.id.to_s,
      name: food_item.name,
      aisle: food_item.aisle,
      custom: food_item.family_id.present?
    }
  end

  def self.render_many(food_items)
    food_items.map { |food_item| render(food_item) }
  end
end
