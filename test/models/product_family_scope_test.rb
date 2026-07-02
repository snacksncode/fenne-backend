require "test_helper"

class ProductFamilyScopeTest < ActiveSupport::TestCase
  test "pantry entry rejects product from another family" do
    product = Product.create!(family: families(:johnson_family), name: "Rice", aisle: :pantry, unit: :count)
    entry = PantryEntry.new(family: families(:smith_family), product: product, quantity_remaining: 1, last_acquired: Time.current)

    assert_not entry.valid?
    assert_includes entry.errors[:product], "must belong to family"
  end

  test "grocery item rejects product from another family" do
    product = Product.create!(family: families(:johnson_family), name: "Rice", aisle: :pantry, unit: :count)
    item = GroceryItem.new(
      family: families(:smith_family),
      product: product,
      name: product.name,
      aisle: product.aisle,
      unit: product.unit,
      quantity: 1
    )

    assert_not item.valid?
    assert_includes item.errors[:product], "must belong to family"
  end

  test "ingredient rejects product from another family" do
    product = Product.create!(family: families(:johnson_family), name: "Rice", aisle: :pantry, unit: :count)
    ingredient = Ingredient.new(
      recipe: recipes(:scrambled_eggs_smith),
      product: product,
      unit: :count,
      quantity: 1
    )

    assert_not ingredient.valid?
    assert_includes ingredient.errors[:product], "must belong to recipe family"
  end
end
