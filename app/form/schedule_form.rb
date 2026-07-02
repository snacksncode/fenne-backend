class ScheduleForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :user, :date, :data

  validates :user, :date, :data, presence: true
  validate :validate_meals

  def save
    return false if invalid?

    ActiveRecord::Base.transaction do
      @schedule_day = user.family.schedule_days.find_or_create_by(date:)
      handle_meal(:breakfast, data[:breakfast]) if data.key?(:breakfast)
      handle_meal(:lunch, data[:lunch]) if data.key?(:lunch)
      handle_meal(:dinner, data[:dinner]) if data.key?(:dinner)
      @schedule_day.update(is_shopping_day: data[:is_shopping_day]) if data.key?(:is_shopping_day)
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    errors.merge!(e.record.errors)
    false
  end

  private

  def handle_meal(meal_type, meal)
    ScheduleItem.find_by(schedule_day: @schedule_day, meal_type:)&.destroy
    return if meal.nil?
    ScheduleItem.create!(
      schedule_day: @schedule_day,
      kind: meal[:type],
      meal_type: meal_type,
      recipe_id: scoped_recipe_id(meal),
      dining_out_name: meal[:name]
    )
  end

  def validate_meals
    breakfast = data[:breakfast]
    lunch = data[:lunch]
    dinner = data[:dinner]
    if breakfast.present? && data[:breakfast][:type] == "recipe" && !recipe_available?(breakfast[:recipe_id])
      errors.add(:breakfast, "recipe does not exist")
    end

    if lunch.present? && lunch[:type] == "recipe" && !recipe_available?(lunch[:recipe_id])
      errors.add(:lunch, "recipe does not exist")
    end

    if dinner.present? && dinner[:type] == "recipe" && !recipe_available?(dinner[:recipe_id])
      errors.add(:dinner, "recipe does not exist")
    end
  end

  def recipe_available?(recipe_id)
    user.family.recipes.exists?(recipe_id)
  end

  def scoped_recipe_id(meal)
    return nil unless meal[:type] == "recipe"

    user.family.recipes.find(meal[:recipe_id]).id
  end
end
