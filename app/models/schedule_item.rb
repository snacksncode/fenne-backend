class ScheduleItem < ApplicationRecord
  belongs_to :schedule_day
  belongs_to :recipe, optional: true

  enum :kind, %i[recipe dining_out], prefix: true
  enum :meal_type, %i[breakfast lunch dinner], prefix: true

  validates :recipe_id, presence: true, if: :kind_recipe?
  validates :dining_out_name, presence: true, if: :kind_dining_out?
  validates :meal_type, presence: true
end
