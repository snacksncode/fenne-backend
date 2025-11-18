class Family < ApplicationRecord
  has_many :users
  has_many :grocery_items, dependent: :destroy
end
