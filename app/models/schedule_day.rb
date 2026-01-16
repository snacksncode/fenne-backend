class ScheduleDay < ApplicationRecord
  belongs_to :family
  has_many :schedule_items, dependent: :destroy
  validates :date, presence: true
  validates :date, uniqueness: {scope: :family_id}

  def breakfast
    schedule_items.find { |i| i.meal_type_breakfast? }
  end

  def lunch
    schedule_items.find { |i| i.meal_type_lunch? }
  end

  def dinner
    schedule_items.find { |i| i.meal_type_dinner? }
  end

  scope :in_range, ->(start_date, end_date) {
    where(date: start_date..end_date).order(:date)
  }
end
