class Ingredient < ApplicationRecord
  belongs_to :recipe

  include UnitEnum

  validates :name, :unit, :quantity, presence: true
  validates :quantity, numericality: {greater_than: 0}
end
