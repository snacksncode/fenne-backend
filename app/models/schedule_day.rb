class ScheduleDay < ApplicationRecord
  belongs_to :family
  belongs_to :breakfast_recipe, class_name: "Recipe", optional: true
  belongs_to :lunch_recipe, class_name: "Recipe", optional: true
  belongs_to :dinner_recipe, class_name: "Recipe", optional: true

  validates :date, presence: true
  validates :date, uniqueness: {scope: :family_id}
  validate :recipes_belong_to_family

  scope :in_range, ->(start_date, end_date) {
    where(date: start_date..end_date).order(:date)
  }

  private

  def recipes_belong_to_family
    [breakfast_recipe, lunch_recipe, dinner_recipe].compact.each do |recipe|
      if recipe.family_id != family_id
        errors.add(:base, "recipes should belong to one family")
      end
    end
  end
end
