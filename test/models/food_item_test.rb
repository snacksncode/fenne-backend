require "test_helper"

class FoodItemTest < ActiveSupport::TestCase
  test "validates name presence" do
    food_item = FoodItem.new(aisle: :produce)

    assert_not food_item.valid?
    assert_includes food_item.errors[:name], "can't be blank"
  end

  test "validates aisle presence" do
    food_item = FoodItem.new(name: "Tomato")

    assert_not food_item.valid?
    assert_includes food_item.errors[:aisle], "can't be blank"
  end

  test "belongs to family optionally" do
    food_item_with_family = FoodItem.create!(
      name: "Family-specific item",
      aisle: :produce,
      family: families(:smith_family)
    )
    food_item_without_family = FoodItem.create!(
      name: "Global item",
      aisle: :produce
    )

    assert_instance_of Family, food_item_with_family.family
    assert_nil food_item_without_family.family
  end

  test "valid with name and aisle" do
    food_item = FoodItem.new(name: "Apple", aisle: :produce)

    assert food_item.valid?
  end

  test "valid with family" do
    food_item = FoodItem.new(
      name: "Custom ingredient",
      aisle: :spices_baking,
      family: families(:smith_family)
    )

    assert food_item.valid?
  end
end
