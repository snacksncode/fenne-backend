require "test_helper"

class RecipeTest < ActiveSupport::TestCase
  test "meal_types returns array of meal types from bitmask" do
    recipe = recipes(:pasta_carbonara_smith)
    recipe.update!(meal_types_bitmask: 1)

    assert_equal [:breakfast], recipe.meal_types
  end

  test "meal_types handles multiple meal types" do
    recipe = recipes(:pasta_carbonara_smith)
    recipe.update!(meal_types_bitmask: 3)

    assert_equal [:breakfast, :lunch], recipe.meal_types
  end

  test "meal_types handles all meal types" do
    recipe = recipes(:pasta_carbonara_smith)
    recipe.update!(meal_types_bitmask: 7)

    assert_equal [:breakfast, :lunch, :dinner], recipe.meal_types
  end

  test "meal_types= converts array to bitmask for single type" do
    recipe = Recipe.new(
      family: families(:smith_family),
      name: "Test Recipe",
      time_in_minutes: 30
    )
    recipe.meal_types = [:breakfast]

    assert_equal 1, recipe.meal_types_bitmask
  end

  test "meal_types= converts array to bitmask for multiple types" do
    recipe = Recipe.new(
      family: families(:smith_family),
      name: "Test Recipe",
      time_in_minutes: 30
    )
    recipe.meal_types = [:breakfast, :lunch]

    assert_equal 3, recipe.meal_types_bitmask
  end

  test "meal_types= converts array to bitmask for all types" do
    recipe = Recipe.new(
      family: families(:smith_family),
      name: "Test Recipe",
      time_in_minutes: 30
    )
    recipe.meal_types = [:breakfast, :lunch, :dinner]

    assert_equal 7, recipe.meal_types_bitmask
  end

  test "meal_types= accepts string keys" do
    recipe = Recipe.new(
      family: families(:smith_family),
      name: "Test Recipe",
      time_in_minutes: 30
    )
    recipe.meal_types = ["breakfast", "dinner"]

    assert_equal 5, recipe.meal_types_bitmask
  end

  test "meal_types= raises error if not an array" do
    recipe = Recipe.new(family: families(:smith_family))

    assert_raises(ArgumentError) do
      recipe.meal_types = "breakfast"
    end
  end

  test "validates name presence" do
    recipe = Recipe.new(
      family: families(:smith_family),
      meal_types: [:breakfast],
      time_in_minutes: 30
    )

    assert_not recipe.valid?
    assert_includes recipe.errors[:name], "can't be blank"
  end

  test "validates meal_types presence" do
    recipe = Recipe.new(
      family: families(:smith_family),
      name: "Test Recipe",
      time_in_minutes: 30,
      meal_types_bitmask: 0
    )

    # meal_types returns empty array when bitmask is 0
    assert_equal [], recipe.meal_types

    assert_not recipe.valid?
    assert_includes recipe.errors[:meal_types], "can't be blank"
  end

  test "validates time_in_minutes presence" do
    recipe = Recipe.new(
      family: families(:smith_family),
      name: "Test Recipe",
      meal_types: [:breakfast],
      time_in_minutes: nil
    )

    assert_not recipe.valid?
    assert_includes recipe.errors[:time_in_minutes], "can't be blank"
  end

  test "validates liked is boolean" do
    recipe = Recipe.new(
      family: families(:smith_family),
      name: "Test Recipe",
      meal_types: [:breakfast],
      time_in_minutes: 30,
      liked: nil
    )

    assert_not recipe.valid?
    assert_includes recipe.errors[:liked], "is not included in the list"
  end

  test "validates meal_types_bitmask is between 0 and 7" do
    recipe = Recipe.new(
      family: families(:smith_family),
      name: "Test Recipe",
      time_in_minutes: 30
    )
    recipe.meal_types_bitmask = 8

    assert_not recipe.valid?
    assert_includes recipe.errors[:meal_types_bitmask], "must be less than or equal to 7"
  end

  test "validates time_in_minutes is at least 1" do
    recipe = Recipe.new(
      family: families(:smith_family),
      name: "Test Recipe",
      meal_types: [:breakfast],
      time_in_minutes: 0
    )

    assert_not recipe.valid?
    assert_includes recipe.errors[:time_in_minutes], "must be greater than or equal to 1"
  end

  test "belongs to family" do
    recipe = recipes(:pasta_carbonara_smith)

    assert_instance_of Family, recipe.family
    assert_equal families(:smith_family), recipe.family
  end

  test "has many ingredients" do
    recipe = recipes(:pasta_carbonara_smith)

    assert_respond_to recipe, :ingredients
    assert recipe.ingredients.count > 0
  end

  test "destroys ingredients when recipe is destroyed" do
    recipe = recipes(:pasta_carbonara_smith)
    ingredient_ids = recipe.ingredients.pluck(:id)

    recipe.destroy

    ingredient_ids.each do |ingredient_id|
      assert_not Ingredient.exists?(ingredient_id)
    end
  end

  test "has many schedule items" do
    recipe = recipes(:pasta_carbonara_smith)

    assert_respond_to recipe, :schedule_items
  end

  test "destroys schedule items when recipe is destroyed" do
    recipe = recipes(:pasta_carbonara_smith)
    schedule_item = ScheduleItem.create!(
      schedule_day: ScheduleDay.create!(family: recipe.family, date: Date.today),
      recipe: recipe,
      kind: :recipe,
      meal_type: :breakfast
    )

    recipe.destroy

    assert_not ScheduleItem.exists?(schedule_item.id)
  end
end
