class GroceryItemSerializer
  def self.render(grocery_item, unit_preference: "metric")
    system = unit_preference.to_sym
    display_qty, display_unit = UnitConverter.friendly(grocery_item.quantity.to_f, grocery_item.unit.to_sym, system)
    {
      id: grocery_item.id.to_s,
      name: grocery_item.name,
      quantity: display_qty,
      aisle: grocery_item.aisle,
      unit: display_unit,
      status: grocery_item.status
    }
  end

  def self.render_many(grocery_items, unit_preference: "metric")
    grocery_items.map { |grocery_item| render(grocery_item, unit_preference: unit_preference) }
  end
end
