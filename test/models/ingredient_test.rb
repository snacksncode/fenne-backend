require "test_helper"

class IngredientTest < ActiveSupport::TestCase
  test "validates product presence" do
    ingredient = Ingredient.new(
      recipe: recipes(:pasta_carbonara_smith),
      quantity: 1,
      unit: :cup
    )

    assert_not ingredient.valid?
    assert_includes ingredient.errors[:product], "must exist"
  end

  test "validates unit presence" do
    ingredient = Ingredient.new(
      recipe: recipes(:pasta_carbonara_smith),
      product: products(:smith_fixture_spaghetti),
      quantity: 1
    )

    assert_not ingredient.valid?
    assert_includes ingredient.errors[:unit], "can't be blank"
  end

  test "validates quantity presence" do
    ingredient = Ingredient.new(
      recipe: recipes(:pasta_carbonara_smith),
      product: products(:smith_fixture_spaghetti),
      unit: :cup
    )

    assert_not ingredient.valid?
    assert_includes ingredient.errors[:quantity], "can't be blank"
  end

  test "validates quantity is greater than 0" do
    ingredient = Ingredient.new(
      recipe: recipes(:pasta_carbonara_smith),
      product: products(:smith_fixture_spaghetti),
      quantity: 0,
      unit: :cup
    )

    assert_not ingredient.valid?
    assert_includes ingredient.errors[:quantity], "must be greater than 0"
  end

  test "belongs to recipe" do
    ingredient = ingredients(:pasta_carbonara_pasta)

    assert_instance_of Recipe, ingredient.recipe
  end

  test "valid with all required attributes" do
    ingredient = Ingredient.new(
      recipe: recipes(:pasta_carbonara_smith),
      product: products(:smith_fixture_spaghetti),
      quantity: 2,
      unit: :tbsp
    )

    assert ingredient.valid?
  end

  test "allows optional recipe-side name override" do
    ingredient = Ingredient.new(
      recipe: recipes(:pasta_carbonara_smith),
      product: products(:smith_fixture_eggs),
      name_override: "Yolk",
      quantity: 1,
      unit: :count
    )

    assert ingredient.valid?
  end
end
