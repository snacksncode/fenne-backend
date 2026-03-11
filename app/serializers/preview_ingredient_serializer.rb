class PreviewIngredientSerializer
  def self.render(ingredient, unit_preference:)
    system = unit_preference.to_sym
    base_qty, base_unit = UnitConverter.to_base(ingredient.quantity.to_f, ingredient.unit.to_sym, system)
    display_qty, display_unit = UnitConverter.friendly(base_qty, base_unit, system)
    {
      id: ingredient.id.to_s,
      name: ingredient.name,
      quantity: display_qty,
      unit: display_unit,
      formatted_unit: UnitConverter.pretty_unit(display_qty, display_unit)
    }
  end
end
