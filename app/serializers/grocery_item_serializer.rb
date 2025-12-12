class GroceryItemSerializer
  def self.render(grocery_item)
    {
      id: grocery_item.id.to_s,
      name: grocery_item.name,
      quantity: grocery_item.quantity.to_f,
      aisle: grocery_item.aisle,
      unit: grocery_item.unit,
      status: grocery_item.status
    }
  end

  def self.render_many(grocery_items)
    grocery_items.map { |grocery_item| render(grocery_item) }
  end
end
