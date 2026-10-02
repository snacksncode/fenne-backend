class GroceryItem < ApplicationRecord
  belongs_to :family
  belongs_to :product, optional: true

  enum :status, { pending: 0, completed: 1 }, prefix: true
  enum :source, { generated: 0, manual: 1 }, prefix: true

  scope :detail, -> { includes(product: :pantry_entries) }

  include UnitEnum
  include AisleEnum

  validates :name, :quantity, :aisle, :unit, :source, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validate :product_belongs_to_family
  validates :needed_quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :positive_unplanned_quantity

  def self.add_product!(family:, product:, quantity:, source:, recipe_ids: [], purchase_override: :unchanged)
    transaction do
      item = family.grocery_items.lock.find_or_initialize_by(product: product)
      item.assign_attributes(name: product.name, aisle: product.aisle, unit: product.unit)
      item.source = source if item.new_record?

      if source == "generated" && product.measured?
        item.needed_quantity = (item.needed_quantity || 0) + quantity
        if item.new_record?
          item.quantity_overridden = false
          item.status = "pending"
        end
        if purchase_override != :unchanged
          item.quantity_overridden = !purchase_override.nil?
          item.quantity = purchase_override || item.purchase_suggestion[:suggested_quantity]
        end
        item.quantity = item.purchase_suggestion[:suggested_quantity] unless item.purchase_fixed?
        item.quantity ||= 0
      else
        item.quantity = item.persisted? ? item.purchase_quantity + quantity : quantity
        item.quantity_overridden = true
        item.status = "pending"
      end

      item.recipe_ids = (Array(item.recipe_ids) + recipe_ids).map(&:to_i).uniq
      item.save!
      item
    end
  end

  # Checking freezes the displayed purchase. Editing a quantity separately makes
  # it an override; reopening an unedited suggestion lets it follow Pantry again.
  def update_purchase(attributes)
    if attributes[:use_suggestion] == true
      use_purchase_suggestion
    elsif attributes.key?(:quantity)
      if product && attributes.fetch(:unit, product.unit) != product.unit
        raise ArgumentError, "incompatible unit"
      end
      self.quantity = attributes[:quantity]
      self.quantity_overridden = true unless attributes[:status] == "completed" && !quantity_overridden
    elsif attributes[:status] == "completed"
      self.quantity = purchase_quantity
    end

    self.unit = attributes[:unit] if attributes[:unit].present? && product.nil?
    self.status = attributes[:status] if attributes[:status].present?
    save
  end

  def purchase_fixed?
    quantity_overridden || status_completed?
  end

  def purchase_suggestion
    return nil unless product&.measured? && !needed_quantity.nil?

    PurchaseSuggestion.call(product: product, needed: needed_quantity)
  end

  def purchase_quantity
    suggestion = purchase_suggestion
    suggestion && !purchase_fixed? ? suggestion[:suggested_quantity].to_d : quantity
  end

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

  # Checkout has already added the frozen purchase to Pantry. Re-read that stock
  # before deciding whether the Recipe requirement still needs another purchase.
  def finish_checkout!
    product&.pantry_entries&.reset
    suggestion = purchase_suggestion
    if suggestion && suggestion[:shortage] > 0
      update!(status: :pending, quantity_overridden: false, quantity: suggestion[:suggested_quantity])
    else
      destroy!
    end
  end

  private

  def use_purchase_suggestion
    suggestion = purchase_suggestion
    raise ArgumentError, "No recipe requirement to calculate from" unless suggestion

    self.quantity_overridden = false
    self.quantity = suggestion[:suggested_quantity]
  end

  def positive_unplanned_quantity
    errors.add(:quantity, "must be greater than 0") if quantity && quantity <= 0 && !(product&.measured? && needed_quantity)
  end

  def product_belongs_to_family
    return if product.nil?
    return if product.family_id == family_id

    errors.add(:product, "must belong to family")
  end
end
