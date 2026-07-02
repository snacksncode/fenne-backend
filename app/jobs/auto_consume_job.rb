class AutoConsumeJob < ApplicationJob
  queue_as :default

  def perform(now = Time.current)
    Family.where.not(timezone: nil).find_each do |family|
      zone = ActiveSupport::TimeZone[family.timezone]
      next unless zone

      local_now = now.in_time_zone(zone)
      next unless local_now.hour == 4

      consume_yesterday_for_family!(family, local_now.to_date - 1.day)
    end
  end

  private

  def consume_yesterday_for_family!(family, date)
    schedule_day = family.schedule_days.includes(schedule_items: { recipe: { ingredients: :product } }).find_by(date: date)
    return unless schedule_day

    touched = false
    schedule_day.schedule_items.kind_recipe.each do |schedule_item|
      recipe = schedule_item.recipe

      ApplicationRecord.transaction do
        deductions = ConsumptionDeductor.call(family: family, recipe: recipe)
        family.consumption_logs.create!(
          recipe_name: recipe.name,
          meal_type: schedule_item.meal_type,
          schedule_date: date,
          deductions: deductions
        )
        family.consumption_logs.stale.destroy_all
        touched = true
      rescue ArgumentError => e
        Rails.logger.warn(
          "AutoConsumeJob: skipping recipe_id=#{recipe.id} family_id=#{family.id} " \
          "(#{e.class}: #{e.message})"
        )
        raise ActiveRecord::Rollback
      rescue ActiveRecord::RecordNotUnique
        raise ActiveRecord::Rollback
      end
    end

    return unless touched

    QueryInvalidator.broadcast(:consumption_logs, family)
    QueryInvalidator.broadcast(:pantry_entries, family)
  end
end
