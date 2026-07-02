class ProductSuggestionSerializer
  def self.render(suggestion)
    {
      id: suggestion.id.to_s,
      name: suggestion.name,
      aisle: suggestion.aisle
    }
  end

  def self.render_many(suggestions)
    suggestions.map { |suggestion| render(suggestion) }
  end
end
