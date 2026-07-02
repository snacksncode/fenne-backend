module V2
  class SuggestionsController < ApplicationController
    class IndexContract < Dry::Validation::Contract
      params do
        required(:q).filled(:string)
        optional(:context).filled(:string, included_in?: %w[shopping pantry recipe])
      end
    end

    def index
      attrs = validate_params!(IndexContract)
      q = attrs[:q].strip

      context = attrs.fetch(:context, "recipe").to_s
      results = ProductSearchIndex.search(query: q, family: @current_user.family, context:)

      render_success({
        results: results.map { |result| render_search_result(result) },
        add_available: ProductSearchIndex.add_available?(q, family: @current_user.family, context:)
      })
    end

    private

    def render_search_result(result)
      if result[:type] == :product
        ProductSerializer.render(result[:record]).merge(type: "product")
      else
        ProductSuggestionSerializer.render(result[:record]).merge(type: "suggestion")
      end
    end
  end
end
