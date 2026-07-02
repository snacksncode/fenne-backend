class PantryEntry < ApplicationRecord
  belongs_to :family
  belongs_to :product

  scope :detail, -> { includes(:product) }

  validates :product_id, uniqueness: { scope: :family_id }
  validates :quantity_remaining, numericality: { greater_than_or_equal_to: 0 }
  validate :product_belongs_to_family

  private

  def product_belongs_to_family
    return if product.nil?
    return if product.family_id == family_id

    errors.add(:product, "must belong to family")
  end
end
