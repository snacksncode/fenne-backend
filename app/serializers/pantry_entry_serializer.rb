class PantryEntrySerializer
  def self.render(entry)
    {
      id: entry.id.to_s,
      product_id: entry.product_id.to_s,
      product: ProductSerializer.render(entry.product),
      quantity_remaining: entry.quantity_remaining.to_f,
      last_acquired: entry.last_acquired&.iso8601
    }
  end

  def self.render_many(entries)
    entries.map { |entry| render(entry) }
  end
end
