require "test_helper"

class ScheduleDayTest < ActiveSupport::TestCase
  test "breakfast returns breakfast schedule item" do
    schedule_day = schedule_days(:tomorrow)
    breakfast_item = schedule_day.schedule_items.create!(
      kind: :recipe,
      meal_type: :breakfast,
      recipe: recipes(:pasta_carbonara_smith)
    )

    assert_equal breakfast_item, schedule_day.breakfast
  end

  test "lunch returns lunch schedule item" do
    schedule_day = schedule_days(:tomorrow)
    lunch_item = schedule_day.schedule_items.create!(
      kind: :recipe,
      meal_type: :lunch,
      recipe: recipes(:pasta_carbonara_smith)
    )

    assert_equal lunch_item, schedule_day.lunch
  end

  test "dinner returns dinner schedule item" do
    schedule_day = schedule_days(:tomorrow)
    dinner_item = schedule_day.schedule_items.create!(
      kind: :recipe,
      meal_type: :dinner,
      recipe: recipes(:pasta_carbonara_smith)
    )

    assert_equal dinner_item, schedule_day.dinner
  end

  test "meal helpers return nil when no item exists" do
    schedule_day = ScheduleDay.create!(family: families(:smith_family), date: Date.today)

    assert_nil schedule_day.breakfast
    assert_nil schedule_day.lunch
    assert_nil schedule_day.dinner
  end

  test "in_range scope returns schedule days in date range" do
    family = families(:smith_family)
    start_date = Date.today + 20.days
    end_date = Date.today + 25.days

    day1 = ScheduleDay.create!(family: family, date: start_date)
    day2 = ScheduleDay.create!(family: family, date: start_date + 2.days)
    day3 = ScheduleDay.create!(family: family, date: end_date)
    outside_range = ScheduleDay.create!(family: family, date: end_date + 1.day)

    result = ScheduleDay.in_range(start_date, end_date)

    assert_includes result, day1
    assert_includes result, day2
    assert_includes result, day3
    assert_not_includes result, outside_range
  end

  test "in_range scope orders by date" do
    family = families(:smith_family)
    start_date = Date.today + 30.days
    end_date = Date.today + 35.days

    day3 = ScheduleDay.create!(family: family, date: end_date)
    day1 = ScheduleDay.create!(family: family, date: start_date)
    day2 = ScheduleDay.create!(family: family, date: start_date + 2.days)

    result = ScheduleDay.in_range(start_date, end_date).to_a

    assert_equal [day1, day2, day3], result
  end

  test "validates date presence" do
    schedule_day = ScheduleDay.new(family: families(:smith_family))

    assert_not schedule_day.valid?
    assert_includes schedule_day.errors[:date], "can't be blank"
  end

  test "validates date uniqueness per family" do
    existing = schedule_days(:tomorrow)
    duplicate = ScheduleDay.new(
      family: existing.family,
      date: existing.date
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:date], "has already been taken"
  end

  test "allows same date for different families" do
    date = Date.today
    ScheduleDay.create!(family: families(:smith_family), date: date)
    schedule_day = ScheduleDay.new(family: families(:johnson_family), date: date)

    assert schedule_day.valid?
  end

  test "belongs to family" do
    schedule_day = schedule_days(:tomorrow)

    assert_instance_of Family, schedule_day.family
  end

  test "has many schedule items" do
    schedule_day = schedule_days(:tomorrow)

    assert_respond_to schedule_day, :schedule_items
  end

  test "destroys schedule items when schedule day is destroyed" do
    schedule_day = schedule_days(:tomorrow)
    item = schedule_day.schedule_items.create!(
      kind: :recipe,
      meal_type: :breakfast,
      recipe: recipes(:pasta_carbonara_smith)
    )

    schedule_day.destroy

    assert_not ScheduleItem.exists?(item.id)
  end
end
