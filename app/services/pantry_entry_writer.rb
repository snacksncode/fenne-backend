class PantryEntryWriter
  include ActiveModel::Model

  attr_reader :entry, :actually_deducted

  def initialize(family:, product: nil, entry: nil)
    @family = family
    @entry = entry
    @product = product || entry&.product
    @created = false
  end

  def add(quantity_remaining: nil, last_acquired: nil)
    return false unless product_present?
    return false unless pantry_allowed?
    return false unless valid_last_acquired?(last_acquired)

    PantryEntry.transaction do
      raise InvalidWriterState unless product.timed? || valid_positive_quantity?(quantity_remaining)

      @entry = family.pantry_entries.lock.find_or_initialize_by(product: product)
      @created = entry.new_record?
      entry.quantity_remaining = product.timed? ? 0 : entry.quantity_remaining.to_d + decimal_quantity(quantity_remaining)
      entry.last_acquired = acquired_at(last_acquired)
      entry.save!
    end

    true
  rescue ActiveRecord::RecordInvalid => exception
    errors.merge!(exception.record.errors)
    false
  rescue InvalidWriterState
    false
  end

  def set(quantity_remaining: nil, last_acquired: nil)
    return false unless product_present?
    return false unless pantry_allowed?
    return false unless valid_last_acquired?(last_acquired)

    PantryEntry.transaction do
      if quantity_remaining.present? && !product.timed?
        quantity = decimal_quantity(quantity_remaining)
        if quantity <= 0
          entry.destroy!
        else
          entry.quantity_remaining = quantity
        end
      end

      unless entry.destroyed?
        entry.quantity_remaining = 0 if product.timed?
        entry.last_acquired = acquired_at(last_acquired) if last_acquired.present?
        entry.save!
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => exception
    errors.merge!(exception.record.errors)
    false
  rescue InvalidWriterState
    false
  end

  def deduct(quantity:)
    return false unless product_present?
    return true if product.kitchen_basic? || product.timed?

    PantryEntry.transaction do
      @entry = family.pantry_entries.lock.find_by(product: product)
      if entry
        intended = decimal_quantity(quantity)
        @actually_deducted = [ entry.quantity_remaining.to_d, intended ].min

        if actually_deducted.to_d > 0
          remaining = entry.quantity_remaining.to_d - intended
          if remaining <= 0
            entry.destroy!
          else
            entry.update!(quantity_remaining: remaining)
          end
        end
      end
    end

    true
  rescue ActiveRecord::RecordInvalid => exception
    errors.merge!(exception.record.errors)
    false
  end

  def restore(quantity:, last_acquired: Time.current)
    return false unless product_present?
    return false unless pantry_allowed?

    PantryEntry.transaction do
      @entry = family.pantry_entries.lock.find_or_initialize_by(product: product)
      @created = entry.new_record?
      entry.quantity_remaining = product.timed? ? 0 : entry.quantity_remaining.to_d + decimal_quantity(quantity)
      entry.last_acquired = last_acquired if entry.new_record?
      entry.save!
    end

    true
  rescue ActiveRecord::RecordInvalid => exception
    errors.merge!(exception.record.errors)
    false
  end

  def created?
    @created
  end

  private

  class InvalidWriterState < StandardError; end

  attr_reader :family, :product

  def product_present?
    return true if product.present?

    errors.add(:product, "is required")
    false
  end

  def pantry_allowed?
    return true unless product.kitchen_basic?

    errors.add(:product, "cannot be a kitchen basic")
    false
  end

  def valid_positive_quantity?(quantity)
    return true if decimal_quantity(quantity) > 0

    errors.add(:quantity_remaining, "must be greater than 0")
    false
  end

  def valid_last_acquired?(value)
    acquired_at(value)
    true
  rescue ArgumentError
    errors.add(:last_acquired, "must be a valid timestamp")
    false
  end

  def acquired_at(value)
    value.present? ? Time.zone.iso8601(value) : Time.current
  end

  def decimal_quantity(value)
    BigDecimal(value.to_s)
  rescue ArgumentError
    0.to_d
  end
end
