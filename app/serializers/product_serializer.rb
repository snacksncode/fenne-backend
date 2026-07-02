class ProductSerializer
  def self.render(product)
    {
      id: product.id.to_s,
      name: product.name,
      aisle: product.aisle,
      quantity: product.quantity&.to_f,
      unit: product.unit,
      pack_count: product.pack_count,
      reminder_frequency_value: product.reminder_frequency_value,
      reminder_frequency_unit: product.reminder_frequency_unit,
      is_kitchen_basic: product.is_kitchen_basic,
      shape: product.shape.to_s,
      conversions: product.conversions || {}
    }
  end

  def self.render_many(products)
    products.map { |product| render(product) }
  end
end
