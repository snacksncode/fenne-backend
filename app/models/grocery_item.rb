class GroceryItem < ApplicationRecord
  belongs_to :family

  enum :aisle, {
    produce: 0, bakery: 1, dairy_eggs: 2, meat: 3, seafood: 4,
    pantry: 5, frozen_foods: 6, beverages: 7, snacks: 8,
    condiments_sauces: 9, spices_baking: 10, household: 11,
    personal_care: 12, pet_supplies: 13, other: 14
  }, prefix: true

  include UnitEnum

  validates :name, :quantity, :aisle, :unit, presence: true
  validates :quantity, numericality: {greater_than: 0}
end
