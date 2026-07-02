class GroceryItem < ApplicationRecord
  belongs_to :family
  belongs_to :product, optional: true

  enum :status, { pending: 0, completed: 1 }, prefix: true
  enum :source, { generated: 0, manual: 1 }, prefix: true

  scope :detail, -> { includes(:product) }

  include UnitEnum
  include AisleEnum

  validates :name, :quantity, :aisle, :unit, :source, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validate :product_belongs_to_family

  def recipes
    ids = normalized_recipe_ids
    return Recipe.none if ids.empty?

    family.recipes.where(id: ids)
  end

  def self.recipes_by_id_for(grocery_items)
    items = grocery_items.to_a
    ids = items.flat_map(&:normalized_recipe_ids).uniq
    family_ids = items.map(&:family_id).uniq
    return {} if ids.empty? || family_ids.empty?

    Recipe.where(id: ids, family_id: family_ids).index_by(&:id)
  end

  def normalized_recipe_ids
    Array(recipe_ids).map(&:to_i).reject(&:zero?)
  end

  private

  def product_belongs_to_family
    return if product.nil?
    return if product.family_id == family_id

    errors.add(:product, "must belong to family")
  end
end
