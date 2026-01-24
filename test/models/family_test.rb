require "test_helper"

class FamilyTest < ActiveSupport::TestCase
  test "has many users" do
    family = families(:smith_family)

    assert_respond_to family, :users
    assert family.users.count > 0
    assert_instance_of User, family.users.first
  end

  test "has many grocery items" do
    family = families(:smith_family)

    assert_respond_to family, :grocery_items
    assert family.grocery_items.count > 0
  end

  test "has many recipes" do
    family = families(:smith_family)

    assert_respond_to family, :recipes
    assert family.recipes.count > 0
  end

  test "has many schedule days" do
    family = families(:smith_family)

    assert_respond_to family, :schedule_days
  end

  test "has many food items" do
    family = families(:smith_family)

    assert_respond_to family, :food_items
  end

  test "destroys grocery items when family is destroyed" do
    family = Family.create!
    grocery_item = GroceryItem.create!(family: family, name: "Test", quantity: 1, aisle: :produce, unit: :count)

    family.destroy

    assert_not GroceryItem.exists?(grocery_item.id)
  end

  test "destroys recipes when family is destroyed" do
    family = Family.create!
    recipe = Recipe.create!(family: family, name: "Test", meal_types: [:breakfast], time_in_minutes: 30)

    family.destroy

    assert_not Recipe.exists?(recipe.id)
  end

  test "destroys schedule days when family is destroyed" do
    family = Family.create!
    schedule_day = ScheduleDay.create!(family: family, date: Date.today)

    family.destroy

    assert_not ScheduleDay.exists?(schedule_day.id)
  end

  test "destroys food items when family is destroyed" do
    family = Family.create!
    food_item = FoodItem.create!(family: family, name: "Test Item", aisle: :produce)

    family.destroy

    assert_not FoodItem.exists?(food_item.id)
  end
end
