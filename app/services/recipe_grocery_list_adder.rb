class RecipeGroceryListAdder
  def self.call(family:, recipe:)
    new(family: family, recipe: recipe).call
  end

  def initialize(family:, recipe:)
    @family = family
    @recipe = recipe
  end

  def call
    ApplicationRecord.transaction do
      product_needs.each do |product, quantity|
        next if quantity <= 0

        GroceryItem.add_product!(
          family: family,
          product: product,
          quantity: quantity,
          source: "generated",
          recipe_ids: [ recipe.id ]
        )
      end
    end
  end

  private

  attr_reader :family, :recipe

  def product_needs
    recipe.ingredients.includes(:product)
      .reject { |ingredient| ingredient.product.kitchen_basic? }
      .group_by(&:product)
      .transform_values do |ingredients|
        ingredients.sum { |ingredient| ProductQuantity.ingredient_need(ingredient) }
      end
  end
end
