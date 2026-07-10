class ProductForm
  include ActiveModel::Model

  attr_accessor :id, :family, :name, :aisle, :quantity, :unit, :pack_count,
    :reminder_frequency_value, :reminder_frequency_unit, :is_kitchen_basic,
    :conversions, :impact_acknowledged

  attr_reader :target, :impact, :missing_conversions

  def initialize(attributes = {})
    @submitted_fields = attributes.to_h.symbolize_keys
    super
  end

  def call
    @impact = []
    ActiveRecord::Base.transaction do
      product = id.present? ? family.products.lock.find(id) : family.products.new
      @target = product
      previous_shape = product.persisted? ? product.shape : nil
      previous_unit = product.unit
      previous_conversions = product.conversions.to_h

      assign_product(product)
      normalize_conversions_for_unit_change!(product, previous_shape, previous_unit, previous_conversions)
      validate_update!(product, previous_shape, previous_unit) if product.persisted?

      product.save!
      ProductQuantityMigrator.call(product: product, previous_shape: previous_shape, previous_unit: previous_unit)
      handle_acknowledged_impact!(product) if impact.any?
    end

    errors.none?
  rescue ActiveRecord::RecordInvalid => e
    merge_record_errors(e.record)
    false
  rescue ActiveRecord::RecordNotUnique
    @name_collision = true
    errors.add(:name, "already exists")
    false
  end

  def name_collision?
    @name_collision == true
  end

  private

  def validate_update!(product, previous_shape, previous_unit)
    missing = missing_recipe_conversions(product)
    if missing.any?
      @missing_conversions = missing
      errors.add(:missing_conversions, "missing")
      raise ActiveRecord::Rollback
    end

    @impact = ProductImpactAnalyzer.call(
      product: product,
      previous_shape: previous_shape,
      previous_unit: previous_unit
    )
    if impact.any? && impact_acknowledged != true
      errors.add(:impact, impact)
      raise ActiveRecord::Rollback
    end
  end

  def assign_product(product)
    product.name = name if field_supplied?(:name)
    product.aisle = aisle if field_supplied?(:aisle)
    product.quantity = decimal_or_nil(quantity) if field_supplied?(:quantity)
    product.unit = unit if field_supplied?(:unit)
    product.pack_count = integer_or_nil(pack_count) if field_supplied?(:pack_count)
    product.reminder_frequency_value = integer_or_nil(reminder_frequency_value) if field_supplied?(:reminder_frequency_value)
    product.reminder_frequency_unit = reminder_frequency_unit if field_supplied?(:reminder_frequency_unit)
    product.is_kitchen_basic = is_kitchen_basic if field_supplied?(:is_kitchen_basic)
    product.conversions = merged_conversions(product.conversions, conversions) if field_supplied?(:conversions)
  end

  def field_supplied?(field)
    @submitted_fields.key?(field)
  end

  def merged_conversions(current, supplied)
    (current || {}).merge((supplied || {}).to_h.transform_keys(&:to_s))
  end

  def normalize_conversions_for_unit_change!(product, previous_shape, previous_unit, previous_conversions)
    return unless previous_shape == :measured && product.shape == :measured
    return if previous_unit == product.unit

    supplied = field_supplied?(:conversions) ? (conversions || {}).to_h.transform_keys(&:to_s) : {}
    factor = Conversion.factor(previous_unit, product.unit)
    product.conversions = if factor
      converted = previous_conversions.transform_values do |value|
        (BigDecimal(value.to_s) * BigDecimal(factor.to_s)).to_f
      end
      converted.merge(supplied)
    else
      supplied
    end
  end

  def missing_recipe_conversions(product)
    return [] unless product.shape == :measured

    ProductQuantity.missing_ingredient_units(product, product.ingredients.map(&:unit).compact)
  end

  def handle_acknowledged_impact!(product)
    product.pantry_entries.destroy_all if impact.include?("pantry")
    product.grocery_items.destroy_all if impact.include?("shopping_list")
  end

  def decimal_or_nil(value)
    value.blank? ? nil : BigDecimal(value.to_s)
  end

  def integer_or_nil(value)
    value.blank? ? nil : value.to_i
  end

  def merge_record_errors(record)
    record.errors.each { |error| errors.add(error.attribute, error.message) }
  end
end
