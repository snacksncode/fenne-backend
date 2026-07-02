class ConsumptionDeductor
  def self.call(family:, recipe:)
    new(family: family, recipe: recipe).call
  end

  def initialize(family:, recipe:)
    @family = family
    @recipe = recipe
  end

  def call
    deductions = []
    recipe.ingredients.includes(:product).each do |ingredient|
      product = ingredient.product
      next if product.kitchen_basic? || product.shape == :timed

      intended = ProductQuantity.ingredient_need(ingredient)
      writer = PantryEntryWriter.new(family: family, product: product)
      next unless writer.deduct(quantity: intended)

      actually_deducted = writer.actually_deducted.to_d
      next if actually_deducted <= 0

      deductions << {
        product_id: product.id,
        product_name: product.name,
        actually_deducted: actually_deducted.to_s,
        product_unit: product.unit,
        product_shape: product.shape.to_s
      }
    end
    deductions
  end

  private

  attr_reader :family, :recipe
end
