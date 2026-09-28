class ProductSuggestion < ApplicationRecord
  include AisleEnum

  before_validation { self.name = name.to_s.strip }

  validates :name, :aisle, presence: true
  validates :name, uniqueness: { case_sensitive: false }
end
