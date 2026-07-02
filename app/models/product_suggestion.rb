class ProductSuggestion < ApplicationRecord
  include AisleEnum

  before_validation { self.name = name.to_s.strip }
  after_commit :refresh_search_index, on: [ :create, :update ]
  after_commit :remove_search_index, on: :destroy

  validates :name, :aisle, presence: true
  validates :name, uniqueness: { case_sensitive: false }

  private

  def refresh_search_index
    ProductSearchIndex.upsert_suggestion(self)
  end

  def remove_search_index
    ProductSearchIndex.delete("suggestion", id)
  end
end
