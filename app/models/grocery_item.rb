class GroceryItem < ApplicationRecord
  belongs_to :family

  enum :status, {pending: 0, completed: 1}, prefix: true

  include UnitEnum
  include AisleEnum

  validates :name, :quantity, :aisle, :unit, presence: true
  validates :quantity, numericality: {greater_than: 0}
end
