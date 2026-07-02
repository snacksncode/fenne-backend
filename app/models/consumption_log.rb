class ConsumptionLog < ApplicationRecord
  belongs_to :family

  enum :meal_type, { breakfast: 0, lunch: 1, dinner: 2 }, prefix: true

  validates :recipe_name, presence: true

  scope :recent, -> { where("schedule_date >= ?", 14.days.ago.to_date) }
  scope :stale, -> { where("schedule_date < ?", 14.days.ago.to_date) }

  def restore_pantry!
    @partial_restore_failed = false
    product_ids = deductions.map { |snapshot| snapshot.fetch("product_id") }.uniq
    pantry_by_product = family.pantry_entries.where(product_id: product_ids).lock.index_by(&:product_id)

    deductions.each do |snapshot|
      product_id = snapshot.fetch("product_id")
      product = family.products.find_by(id: product_id)

      unless product
        @partial_restore_failed = true
        next
      end

      add_back = restore_quantity(snapshot, product)
      unless add_back
        @partial_restore_failed = true
        next
      end

      writer = PantryEntryWriter.new(family: family, product: product, entry: pantry_by_product[product_id])
      unless writer.restore(quantity: add_back)
        @partial_restore_failed = true
        next
      end
    rescue KeyError, ArgumentError, ActiveRecord::RecordInvalid => e
      @partial_restore_failed = true
      Rails.logger.warn(
        "ConsumptionLog#restore_pantry: skipping product_id=#{snapshot["product_id"].inspect} " \
        "(#{e.class}: #{e.message})"
      )
    end
  end

  def partial_restore_failed?
    @partial_restore_failed == true
  end

  private

  def restore_quantity(snapshot, product)
    quantity = BigDecimal(snapshot.fetch("actually_deducted").to_s)
    snapshot_shape = snapshot["product_shape"]
    snapshot_unit = snapshot["product_unit"]

    return quantity if snapshot_shape.blank? || snapshot_unit.blank?
    return nil unless snapshot_shape == product.shape.to_s
    return quantity if snapshot_unit == product.unit

    factor = Conversion.factor(snapshot_unit, product.unit)
    return nil unless factor

    quantity * BigDecimal(factor.to_s)
  end
end
