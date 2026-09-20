class ProductQuantityMigrator
  def self.call(product:, previous_shape:, previous_unit:)
    new(product: product, previous_shape: previous_shape, previous_unit: previous_unit).call
  end

  def initialize(product:, previous_shape:, previous_unit:)
    @product = product
    @previous_shape = previous_shape
    @previous_unit = previous_unit
  end

  def call
    return unless previous_shape == :measured && product.shape == :measured
    return if previous_unit == product.unit

    factor = Conversion.factor(previous_unit, product.unit)
    return unless factor

    multiplier = BigDecimal(factor.to_s)
    product.pantry_entries.find_each do |entry|
      entry.update!(quantity_remaining: entry.quantity_remaining * multiplier)
    end
    product.grocery_items.find_each do |item|
      item.update!(quantity: item.quantity * multiplier, unit: product.unit,
        needed_quantity: item.needed_quantity && item.needed_quantity * multiplier)
    end
  end

  private

  attr_reader :product, :previous_shape, :previous_unit
end
