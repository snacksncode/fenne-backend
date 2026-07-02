class PreviewIngredientSerializer
  def self.render(ingredient)
    {
      id: ingredient.id.to_s,
      name: ingredient.name_override.presence || ingredient.product.name,
      quantity: ingredient.quantity.to_f,
      unit: ingredient.unit
    }
  end
end
