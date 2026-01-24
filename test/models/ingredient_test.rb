require "test_helper"

class IngredientTest < ActiveSupport::TestCase
  test "validates name presence" do
    ingredient = Ingredient.new(
      recipe: recipes(:pasta_carbonara_smith),
      quantity: 1,
      unit: :cup,
      aisle: :produce
    )

    assert_not ingredient.valid?
    assert_includes ingredient.errors[:name], "can't be blank"
  end

  test "validates unit presence" do
    ingredient = Ingredient.new(
      recipe: recipes(:pasta_carbonara_smith),
      name: "Flour",
      quantity: 1,
      aisle: :produce
    )

    assert_not ingredient.valid?
    assert_includes ingredient.errors[:unit], "can't be blank"
  end

  test "validates aisle presence" do
    ingredient = Ingredient.new(
      recipe: recipes(:pasta_carbonara_smith),
      name: "Flour",
      quantity: 1,
      unit: :cup,
      aisle: nil
    )

    assert_not ingredient.valid?
    assert_includes ingredient.errors[:aisle], "can't be blank"
  end

  test "validates quantity presence" do
    ingredient = Ingredient.new(
      recipe: recipes(:pasta_carbonara_smith),
      name: "Flour",
      unit: :cup,
      aisle: :produce
    )

    assert_not ingredient.valid?
    assert_includes ingredient.errors[:quantity], "can't be blank"
  end

  test "validates quantity is greater than 0" do
    ingredient = Ingredient.new(
      recipe: recipes(:pasta_carbonara_smith),
      name: "Flour",
      quantity: 0,
      unit: :cup,
      aisle: :produce
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
      name: "Sugar",
      quantity: 2,
      unit: :tbsp,
      aisle: :spices_baking
    )

    assert ingredient.valid?
  end
end
