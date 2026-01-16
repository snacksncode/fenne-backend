class FoodItem < ApplicationRecord
  belongs_to :family, optional: true
  include AisleEnum
  validates :name, :aisle, presence: true
end
