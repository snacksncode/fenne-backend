class Ingredient < ApplicationRecord
  belongs_to :recipe
  belongs_to :product

  include UnitEnum

  validates :unit, :quantity, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validate :product_belongs_to_recipe_family

  private

  def product_belongs_to_recipe_family
    return if product.nil?
    return if product.family_id == recipe.family_id

    errors.add(:product, "must belong to recipe family")
  end
end
