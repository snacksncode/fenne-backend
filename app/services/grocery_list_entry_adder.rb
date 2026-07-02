class GroceryListEntryAdder
  def self.call(family:, product:, quantity:, source:, recipe_ids: [])
    new(family: family, product: product, quantity: quantity, source: source, recipe_ids: recipe_ids).call
  end

  def initialize(family:, product:, quantity:, source:, recipe_ids: [])
    @family = family
    @product = product
    @quantity = quantity
    @source = source
    @recipe_ids = recipe_ids
  end

  def call
    item = family.grocery_items.lock.find_or_initialize_by(product: product)
    item.name = product.name
    item.aisle = product.aisle
    item.unit = product.unit
    item.status = "pending"
    item.source = source if item.new_record?
    item.quantity = (item.quantity || 0) + quantity
    item.recipe_ids = (Array(item.recipe_ids) + recipe_ids).map(&:to_i).uniq
    item.save!
    item
  end

  private

  attr_reader :family, :product, :quantity, :source, :recipe_ids
end
