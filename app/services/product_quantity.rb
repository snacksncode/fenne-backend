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
      measured_need(ingredient.quantity.to_d, ingredient.unit, allow_conversions: true)
    when :timed
      running_low? ? 1.to_d : 0.to_d
    end
  end

  def quantity_after_pantry(needed)
    pantry_quantity = product.pantry_entries.first&.quantity_remaining || 0
    missing = needed.to_d - pantry_quantity.to_d
    return 0.to_d if missing <= 0

    round_for_purchase(missing)
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
    return true if unit.to_s == "count"
    return true if Conversion.same_dimension?(unit, product.unit)

    product.conversions.to_h.key?(unit.to_s)
  end

  private

  attr_reader :product

  def measured_need(quantity, unit, allow_conversions:)
    return quantity * product.quantity if unit.to_s == "count"

    factor = Conversion.factor(unit, product.unit)
    return quantity * BigDecimal(factor.to_s) if factor
    raise ArgumentError, "incompatible unit" unless allow_conversions

    conversion = product.conversions.to_h[unit.to_s]
    raise ArgumentError, "missing conversion for #{unit}" if conversion.blank?

    quantity * BigDecimal(conversion.to_s)
  end

  def round_for_purchase(missing)
    return apply_pack_count(missing.ceil) if product.shape == :counted || product.shape == :timed
    return missing if product.quantity.blank?

    packs = (missing / product.quantity).ceil
    packs = apply_pack_count(packs)
    packs * product.quantity
  end

  def apply_pack_count(count)
    return count unless product.pack_count.present?

    (count.to_d / product.pack_count).ceil * product.pack_count
  end

  def reminder_threshold
    case product.reminder_frequency_unit
    when "days" then product.reminder_frequency_value.days
    when "weeks" then product.reminder_frequency_value.weeks
    when "months" then product.reminder_frequency_value.months
    end
  end
end
