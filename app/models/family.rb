class Family < ApplicationRecord
  has_many :users
  has_many :grocery_items, dependent: :destroy
  has_many :recipes, dependent: :destroy
  has_many :schedule_days, dependent: :destroy
  has_many :food_items, dependent: :destroy
end
