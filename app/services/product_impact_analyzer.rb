class ProductImpactAnalyzer
  def self.call(product:, previous_shape:, previous_unit:)
    new(product: product, previous_shape: previous_shape, previous_unit: previous_unit).call
  end

  def initialize(product:, previous_shape:, previous_unit:)
    @product = product
    @previous_shape = previous_shape
    @previous_unit = previous_unit
  end

  def call
    return [] unless previous_shape
    return [] unless destructive_change?

    impact = []
    impact << "pantry" if pantry_stale?
    impact << "shopping_list" if shopping_stale?
    impact.uniq
  end

  private

  attr_reader :product, :previous_shape, :previous_unit

  def destructive_change?
    shape_changed? || incompatible_unit_change? || shopping_metadata_changed?
  end

  def pantry_stale?
    product.pantry_entries.exists? && (shape_changed? || incompatible_unit_change?)
  end

  def shopping_stale?
    return false if equivalent_measured_unit_change? && !non_unit_shopping_metadata_changed?

    product.grocery_items.status_pending.exists? || product.grocery_items.status_completed.exists?
  end

  def shape_changed?
    previous_shape != product.shape
  end

  def incompatible_unit_change?
    previous_shape == :measured &&
      product.shape == :measured &&
      previous_unit != product.unit &&
      !Conversion.same_dimension?(previous_unit, product.unit)
  end

  def shopping_metadata_changed?
    product.will_save_change_to_pack_count? ||
      product.will_save_change_to_quantity? ||
      product.will_save_change_to_reminder_frequency_value? ||
      product.will_save_change_to_reminder_frequency_unit?
  end

  def non_unit_shopping_metadata_changed?
    product.will_save_change_to_pack_count? ||
      product.will_save_change_to_reminder_frequency_value? ||
      product.will_save_change_to_reminder_frequency_unit?
  end

  def equivalent_measured_unit_change?
    return false unless previous_shape == :measured && product.shape == :measured
    return false unless product.will_save_change_to_unit? || product.will_save_change_to_quantity?

    factor = Conversion.factor(previous_unit, product.unit)
    return false unless factor

    old_quantity = product.quantity_was || product.attribute_in_database("quantity")
    return false if old_quantity.blank? || product.quantity.blank?

    BigDecimal(product.quantity.to_s) == BigDecimal(old_quantity.to_s) * BigDecimal(factor.to_s)
  end
end
