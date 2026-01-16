class Recipe < ApplicationRecord
  belongs_to :family
  has_many :ingredients, dependent: :destroy
  has_many :schedule_items, dependent: :destroy

  MEAL_TYPES = {breakfast: 1, lunch: 2, dinner: 4}

  def meal_types
    MEAL_TYPES.select { |_, value| (meal_types_bitmask & value) > 0 }.keys
  end

  def meal_types=(types)
    raise ArgumentError unless types.is_a?(Array)
    self.meal_types_bitmask = types.map { |t| MEAL_TYPES[t.to_sym] }.compact.sum
  end

  validates :name, :meal_types, :time_in_minutes, presence: true
  validates :liked, inclusion: {in: [true, false]}
  validates :meal_types_bitmask, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 7
  }
  validates :time_in_minutes, numericality: {
    greater_than_or_equal_to: 1
  }
end
