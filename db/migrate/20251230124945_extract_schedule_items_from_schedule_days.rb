class ExtractScheduleItemsFromScheduleDays < ActiveRecord::Migration[8.0]
  class ScheduleDay < ApplicationRecord; end

  class ScheduleItem < ApplicationRecord; end

  def up
    ScheduleDay.find_each do |day|
      if day.breakfast_recipe_id
        ScheduleItem.create!(
          schedule_day_id: day.id,
          recipe_id: day.breakfast_recipe_id,
          meal_type: 0,
          kind: 0
        )
      end

      if day.lunch_recipe_id
        ScheduleItem.create!(
          schedule_day_id: day.id,
          recipe_id: day.lunch_recipe_id,
          meal_type: 1,
          kind: 0
        )
      end

      if day.dinner_recipe_id
        ScheduleItem.create!(
          schedule_day_id: day.id,
          recipe_id: day.dinner_recipe_id,
          meal_type: 2,
          kind: 0
        )
      end
    end
  end

  def down
    ScheduleItem.delete_all
  end
end
