module V2
  class ProductsController < ApplicationController
    UNIT_TYPES = Product.units.keys.map(&:to_s).freeze
    AISLE_TYPES = Product.aisles.keys.map(&:to_s).freeze

    class CreateProductContract < Dry::Validation::Contract
      params do
        required(:name).filled(:string)
        required(:aisle).filled(:string, included_in?: AISLE_TYPES)
        required(:unit).filled(:string, included_in?: UNIT_TYPES)
        optional(:reminder_frequency_value).maybe(:integer, gt?: 0)
        optional(:reminder_frequency_unit).maybe(:string, included_in?: %w[days weeks months])
        optional(:is_kitchen_basic).filled(:bool)
        optional(:impact_acknowledged).filled(:bool)
        optional(:pack_sizes).value(:array, max_size?: 6).each(:float, gt?: 0, lteq?: 1_000_000)
        optional(:conversions).hash
      end
    end

    class UpdateProductContract < Dry::Validation::Contract
      params do
        optional(:name).filled(:string)
        optional(:aisle).filled(:string, included_in?: AISLE_TYPES)
        optional(:unit).filled(:string, included_in?: UNIT_TYPES)
        optional(:reminder_frequency_value).maybe(:integer, gt?: 0)
        optional(:reminder_frequency_unit).maybe(:string, included_in?: %w[days weeks months])
        optional(:is_kitchen_basic).filled(:bool)
        optional(:impact_acknowledged).filled(:bool)
        optional(:pack_sizes).value(:array, max_size?: 6).each(:float, gt?: 0, lteq?: 1_000_000)
        optional(:conversions).hash
      end
    end

    class NameCollisionContract < Dry::Validation::Contract
      params do
        required(:q).filled(:string)
        optional(:id).filled(:integer)
      end
    end

    class PurchaseSuggestionContract < Dry::Validation::Contract
      params do
        required(:needed).filled(:float, gteq?: 0, lteq?: 1_000_000_000)
        required(:pantry).filled(:float, gteq?: 0, lteq?: 1_000_000_000)
      end
    end

    def index
      render_success(ProductSerializer.render_many(products.order(:name)))
    end

    def show
      render_success(ProductSerializer.render(product))
    end

    def usages
      render_success({ recipes: RecipeSerializer.render_many(product.recipes.includes(ingredients: :product).order(:name)) })
    end

    def purchase_suggestion
      attrs = validate_params!(PurchaseSuggestionContract)
      unless product.measured? || product.counted?
        return render_error({ base: ["This item does not track pantry amounts."] })
      end

      render_success(PurchaseSuggestion.call(product: product, **attrs))
    end

    def create
      form = ProductForm.new(product_params(CreateProductContract).merge(family: @current_user.family))
      if form.call
        invalidate_products!
        render_success(ProductSerializer.render(form.target), status: :created)
      elsif form.name_collision?
        render_error(form.errors, status: :conflict)
      else
        render_error(form.errors)
      end
    end

    def update
      form = ProductForm.new(product_params(UpdateProductContract).merge(id: params[:id], family: @current_user.family))
      if form.call
        invalidate_products!
        invalidate_pantry!
        invalidate_groceries!
        invalidate_recipes!
        render_success(ProductSerializer.render(form.target))
      elsif form.errors.attribute_names.include?(:impact)
        render_error({ impact: form.impact }, status: :precondition_required)
      elsif form.missing_conversions.present?
        render_error({ missing_conversions: form.missing_conversions })
      elsif form.name_collision?
        render_error(form.errors, status: :conflict)
      else
        render_error(form.errors)
      end
    end

    def destroy
      return render_product_delete_error unless product.destroy

      invalidate_products!
      invalidate_pantry!
      invalidate_groceries!
      render_success
    end

    def name_collision
      attrs = validate_params!(NameCollisionContract)
      q = attrs[:q].strip
      scope = products.where("LOWER(TRIM(name)) = ?", q.downcase)
      scope = scope.where.not(id: attrs[:id]) if attrs[:id].present?
      render_success({ exists: scope.exists? })
    end

    private

    def product_params(contract)
      validate_params!(contract)
    end

    def products
      @current_user.family.products
    end

    def product
      @product ||= products.find(params[:id])
    end

    def render_product_delete_error
      render_error(product_delete_errors, status: :conflict)
    end

    def product_delete_errors
      {
        base: product.errors.full_messages,
        recipes: RecipeSerializer.render_many(Array(product.blocked_by_recipes))
      }
    end
  end
end
