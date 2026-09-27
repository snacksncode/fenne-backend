require "test_helper"

class AutoConsumeJobTest < ActiveJob::TestCase
  test "consumes yesterday scheduled meals at family local 4am" do
    family = families(:smith_family)
    family.update!(timezone: "Europe/Warsaw")
    recipe = recipes(:scrambled_eggs_smith)
    product = Product.create!(family: family, name: "Eggs", aisle: :dairy_eggs, unit: :count)
    ingredients(:scrambled_eggs_eggs).update!(product: product)
    PantryEntry.create!(family: family, product: product, quantity_remaining: 3, last_acquired: Time.current)

    local_now = Time.find_zone!("Europe/Warsaw").local(Date.current.year, Date.current.month, Date.current.day, 4)
    schedule_day = ScheduleDay.create!(family: family, date: local_now.to_date - 1.day)
    ScheduleItem.create!(schedule_day: schedule_day, kind: :recipe, meal_type: :breakfast, recipe: recipe)

    assert_difference("ConsumptionLog.count", 1) do
      AutoConsumeJob.perform_now(local_now)
    end

    log = family.consumption_logs.find_by(schedule_date: schedule_day.date, meal_type: :breakfast)
    assert_equal recipe.name, log.recipe_name
    assert_equal 1.0, PantryEntry.find_by(product: product).quantity_remaining.to_f
  end

  test "skips families without timezone" do
    family = families(:smith_family)
    family.update!(timezone: nil)

    assert_no_difference("ConsumptionLog.count") do
      AutoConsumeJob.perform_now(Time.current)
    end
  end
end
