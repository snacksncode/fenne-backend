class Ingredient < ApplicationRecord
  belongs_to :recipe

  include UnitEnum
  include AisleEnum

  validates :name, :unit, :aisle, :quantity, presence: true
  validates :quantity, numericality: {greater_than: 0}
end
