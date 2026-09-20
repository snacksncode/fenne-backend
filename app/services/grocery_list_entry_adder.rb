class GroceryListEntryAdder
  def self.call(family:, product:, quantity:, source:, recipe_ids: [], purchase_override: :unchanged)
    new(family: family, product: product, quantity: quantity, source: source,
      recipe_ids: recipe_ids, purchase_override: purchase_override).call
  end

  def initialize(family:, product:, quantity:, source:, recipe_ids: [], purchase_override: :unchanged)
    @family, @product, @quantity, @source = family, product, quantity, source
    @recipe_ids, @purchase_override = recipe_ids, purchase_override
  end

  def call
    item = family.grocery_items.lock.find_or_initialize_by(product: product)
    item.name, item.aisle, item.unit = product.name, product.aisle, product.unit
    if source == "generated" && product.measured?
      was_new = item.new_record?
      item.needed_quantity = (item.needed_quantity || 0) + quantity
      item.source = source if was_new
      item.quantity_overridden = false if was_new
      item.status = "pending" if was_new
      if purchase_override != :unchanged
        item.quantity_overridden = !purchase_override.nil?
        item.quantity = purchase_override.nil? ? item.purchase_suggestion[:suggested_quantity] : purchase_override
      end
      item.quantity = item.purchase_suggestion[:suggested_quantity] if !item.quantity_overridden && item.status_pending?
      item.quantity ||= 0
    else
      item.quantity = item.purchase_quantity + quantity if item.persisted?
      item.quantity = quantity if item.new_record?
      item.quantity_overridden = true
      item.status = "pending"
      item.source = source if item.new_record?
    end
    item.recipe_ids = (Array(item.recipe_ids) + recipe_ids).map(&:to_i).uniq
    item.save!
    item
  end

  private

  attr_reader :family, :product, :quantity, :source, :recipe_ids, :purchase_override
end
