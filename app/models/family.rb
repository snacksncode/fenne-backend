class Family < ApplicationRecord
  has_many :users
  has_many :grocery_items, dependent: :destroy
  has_many :recipes, dependent: :destroy
  has_many :schedule_days, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :pantry_entries, dependent: :destroy
  has_many :consumption_logs, dependent: :destroy
end
