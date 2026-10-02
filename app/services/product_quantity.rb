class ProductQuantity
  def self.ingredient_need(ingredient)
    new(ingredient.product).ingredient_need(ingredient)
  end

  def self.quantity_after_pantry(product, needed)
    new(product).quantity_after_pantry(needed)
  end

  def self.running_low?(product)
    new(product).running_low?
  end

  def self.ingredient_unit_compatible?(product, unit)
    new(product).ingredient_unit_compatible?(unit)
  end

  def self.missing_ingredient_units(product, units)
    units.map(&:to_s).uniq.reject { |unit| ingredient_unit_compatible?(product, unit) }
  end

  def initialize(product)
    @product = product
  end

  def ingredient_need(ingredient)
    return 0.to_d if product.kitchen_basic?

    case product.shape
    when :counted
      ingredient.unit_count? ? ingredient.quantity.to_d : 1.to_d
    when :measured
      measured_need(ingredient.quantity.to_d, ingredient.unit)
    when :timed
      running_low? ? 1.to_d : 0.to_d
    end
  end

  def quantity_after_pantry(needed)
    pantry_quantity = product.pantry_entries.first&.quantity_remaining || 0
    missing = needed.to_d - pantry_quantity.to_d
    return 0.to_d if missing <= 0

    product.counted? ? missing.ceil : missing
  end

  def running_low?
    entry = product.pantry_entries.first
    return true unless entry

    Time.current >= entry.last_acquired + (reminder_threshold * 0.75)
  end

  def ingredient_unit_compatible?(unit)
    return true if product.kitchen_basic?
    return true if product.shape == :timed
    return true if product.shape == :counted
    return true if Conversion.same_dimension?(unit, product.unit)

    product.conversions.to_h.key?(unit.to_s)
  end

  private

  attr_reader :product

  def measured_need(quantity, unit)
    factor = Conversion.factor(unit, product.unit)
    return quantity * BigDecimal(factor.to_s) if factor

    conversion = product.conversions.to_h[unit.to_s]
    raise ArgumentError, "missing conversion for #{unit}" if conversion.blank?

    quantity * BigDecimal(conversion.to_s)
  end

  def reminder_threshold
    case product.reminder_frequency_unit
    when "days" then product.reminder_frequency_value.days
    when "weeks" then product.reminder_frequency_value.weeks
    when "months" then product.reminder_frequency_value.months
    end
  end
end
