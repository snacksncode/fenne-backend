module V2
  class ProductCatalogController < ApplicationController
    def index
      render_success({
        products: ProductSerializer.render_many(@current_user.family.products.order(:id)),
        suggestions: ProductSuggestionSerializer.render_many(ProductSuggestion.order(:id))
      })
    end
  end
end
