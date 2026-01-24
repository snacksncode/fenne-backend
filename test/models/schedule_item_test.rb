require "test_helper"

class ScheduleItemTest < ActiveSupport::TestCase
  test "kind enum has recipe and dining_out options" do
    schedule_day = schedule_days(:tomorrow)
    item = ScheduleItem.new(schedule_day: schedule_day, meal_type: :breakfast)

    item.kind = :recipe
    assert item.kind_recipe?
    assert_not item.kind_dining_out?

    item.kind = :dining_out
    assert item.kind_dining_out?
    assert_not item.kind_recipe?
  end

  test "meal_type enum has breakfast, lunch, and dinner options" do
    schedule_day = schedule_days(:tomorrow)
    item = ScheduleItem.new(schedule_day: schedule_day, kind: :dining_out, dining_out_name: "Restaurant")

    item.meal_type = :breakfast
    assert item.meal_type_breakfast?
    assert_not item.meal_type_lunch?
    assert_not item.meal_type_dinner?

    item.meal_type = :lunch
    assert item.meal_type_lunch?
    assert_not item.meal_type_breakfast?
    assert_not item.meal_type_dinner?

    item.meal_type = :dinner
    assert item.meal_type_dinner?
    assert_not item.meal_type_breakfast?
    assert_not item.meal_type_lunch?
  end

  test "validates recipe_id presence when kind is recipe" do
    schedule_day = schedule_days(:tomorrow)
    item = ScheduleItem.new(
      schedule_day: schedule_day,
      kind: :recipe,
      meal_type: :breakfast
    )

    assert_not item.valid?
    assert_includes item.errors[:recipe_id], "can't be blank"
  end

  test "does not validate recipe_id when kind is dining_out" do
    schedule_day = schedule_days(:tomorrow)
    item = ScheduleItem.new(
      schedule_day: schedule_day,
      kind: :dining_out,
      meal_type: :breakfast,
      dining_out_name: "Restaurant"
    )

    assert item.valid?
  end

  test "validates dining_out_name presence when kind is dining_out" do
    schedule_day = schedule_days(:tomorrow)
    item = ScheduleItem.new(
      schedule_day: schedule_day,
      kind: :dining_out,
      meal_type: :breakfast
    )

    assert_not item.valid?
    assert_includes item.errors[:dining_out_name], "can't be blank"
  end

  test "does not validate dining_out_name when kind is recipe" do
    schedule_day = schedule_days(:tomorrow)
    item = ScheduleItem.new(
      schedule_day: schedule_day,
      kind: :recipe,
      meal_type: :breakfast,
      recipe: recipes(:pasta_carbonara_smith)
    )

    assert item.valid?
  end

  test "validates meal_type presence" do
    schedule_day = schedule_days(:tomorrow)
    item = ScheduleItem.new(
      schedule_day: schedule_day,
      kind: :dining_out,
      dining_out_name: "Restaurant"
    )

    assert_not item.valid?
    assert_includes item.errors[:meal_type], "can't be blank"
  end

  test "belongs to schedule_day" do
    schedule_day = schedule_days(:tomorrow)
    item = ScheduleItem.create!(
      schedule_day: schedule_day,
      kind: :dining_out,
      meal_type: :breakfast,
      dining_out_name: "Restaurant"
    )

    assert_instance_of ScheduleDay, item.schedule_day
    assert_equal schedule_day, item.schedule_day
  end

  test "belongs to recipe optionally" do
    schedule_day = schedule_days(:tomorrow)
    item_with_recipe = ScheduleItem.create!(
      schedule_day: schedule_day,
      kind: :recipe,
      meal_type: :breakfast,
      recipe: recipes(:pasta_carbonara_smith)
    )
    item_without_recipe = ScheduleItem.create!(
      schedule_day: schedule_day,
      kind: :dining_out,
      meal_type: :lunch,
      dining_out_name: "Restaurant"
    )

    assert_instance_of Recipe, item_with_recipe.recipe
    assert_nil item_without_recipe.recipe
  end

  test "valid when kind is recipe with recipe_id" do
    schedule_day = schedule_days(:tomorrow)
    item = ScheduleItem.new(
      schedule_day: schedule_day,
      kind: :recipe,
      meal_type: :dinner,
      recipe: recipes(:pasta_carbonara_smith)
    )

    assert item.valid?
  end

  test "valid when kind is dining_out with dining_out_name" do
    schedule_day = schedule_days(:tomorrow)
    item = ScheduleItem.new(
      schedule_day: schedule_day,
      kind: :dining_out,
      meal_type: :dinner,
      dining_out_name: "Fancy Restaurant"
    )

    assert item.valid?
  end
end
