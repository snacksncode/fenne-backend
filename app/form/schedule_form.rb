class ScheduleForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :user, :date, :data

  MEAL_TYPES = %i[breakfast lunch dinner].freeze

  validates :user, :date, :data, presence: true
  validate :validate_meals

  def save
    return false if invalid?

    ActiveRecord::Base.transaction do
      @schedule_day = user.family.schedule_days.find_or_create_by(date:)
      MEAL_TYPES.each do |meal_type|
        handle_meal(meal_type, data[meal_type]) if data.key?(meal_type)
      end
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
    MEAL_TYPES.each do |meal_type|
      meal = data[meal_type]
      if meal.present? && meal[:type] == "recipe" && !recipe_available?(meal[:recipe_id])
        errors.add(meal_type, "recipe does not exist")
      end
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
