module V2
  class GroceryItemsController < ApplicationController
    UNIT_TYPES = GroceryItem.units.keys.map(&:to_s).freeze
    AISLE_TYPES = GroceryItem.aisles.keys.map(&:to_s).freeze

    class GenerateContract < Dry::Validation::Contract
      params do
        optional(:start).filled(:string)
        optional(:end).filled(:string)
        optional(:start_date).filled(:string)
        optional(:end_date).filled(:string)
        optional(:checked_product_ids).filled(:array).each(:integer)
        optional(:purchase_quantities).array(:hash) do
          required(:product_id).filled(:integer)
          required(:quantity).maybe(:float, gteq?: 0)
        end
      end

      rule(:start, :end, :start_date, :end_date) do
        has_start = values[:start].present? || values[:start_date].present?
        has_end = values[:end].present? || values[:end_date].present?

        key(:start).failure("is required") unless has_start
        key(:end).failure("is required") unless has_end
      end

      %i[start end start_date end_date].each do |date_key|
        rule(date_key) do
          next unless key?

          Date.iso8601(value)
        rescue ArgumentError
          key.failure("must be ISO8601 date")
        end
      end
    end

    class CreateGroceryItemContract < Dry::Validation::Contract
      params do
        required(:type).filled(:string, included_in?: %w[product custom])
        optional(:product_id).filled(:integer)
        optional(:name).filled(:string)
        optional(:aisle).filled(:string, included_in?: AISLE_TYPES)
        required(:quantity).filled(:float, gt?: 0)
        optional(:unit).filled(:string, included_in?: UNIT_TYPES)
      end

      rule(:type, :product_id, :name, :aisle, :unit) do
        if values[:type] == "product"
          key(:product_id).failure("is required") if values[:product_id].blank?
          key(:unit).failure("is required") if values[:unit].blank?
        end

        if values[:type] == "custom"
          key(:name).failure("is required") if values[:name].blank?
          key(:aisle).failure("is required") if values[:aisle].blank?
          key(:unit).failure("is required") if values[:unit].blank?
        end
      end
    end

    class UpdateGroceryItemContract < Dry::Validation::Contract
      params do
        optional(:quantity).filled(:float, gteq?: 0)
        optional(:use_suggestion).filled(:bool)
        optional(:unit).filled(:string, included_in?: UNIT_TYPES)
        optional(:status).filled(:string, included_in?: GroceryItem.statuses.keys.map(&:to_s))
      end
    end

    class AddFromRecipeContract < Dry::Validation::Contract
      params do
        required(:recipe_id).filled(:integer)
      end
    end

    def index
      # Retain covered recipe demand for later generations, but only show purchases.
      items = grocery_items.detail.select { |item| item.status_completed? || item.purchase_quantity.positive? }
      render_success(GroceryItemSerializer.render_many(items))
    end

    def show
      render_success(GroceryItemSerializer.render(grocery_item))
    end

    def create
      attrs = grocery_item_params
      item = attrs[:type] == "product" ? create_product_backed_item(attrs) : create_custom_item(attrs)

      invalidate_groceries!
      render_success(GroceryItemSerializer.render(item), status: :created)
    rescue ActiveRecord::RecordNotUnique
      render_error({ product_id: [ "already on shopping list" ] }, status: :conflict)
    rescue ArgumentError => e
      render_error({ base: [ e.message ] }, status: :unprocessable_entity)
    rescue ActiveRecord::RecordInvalid => e
      render_error(e.record.errors)
    end

    def update
      item = grocery_item
      attrs = grocery_item_update_params
      if attrs[:use_suggestion] == true
        return render_error({ base: [ "No recipe requirement to calculate from" ] }) unless item.purchase_suggestion
        item.quantity_overridden = false
        item.quantity = item.purchase_suggestion[:suggested_quantity]
      elsif attrs.key?(:quantity)
        validate_product_unit!(item.product, attrs[:unit] || item.product.unit) if item.product
        item.quantity = attrs[:quantity]
        item.quantity_overridden = true unless attrs[:status] == "completed" && !item.quantity_overridden
      elsif attrs[:status] == "completed"
        item.quantity = item.purchase_quantity
      end
      item.unit = attrs[:unit] if attrs[:unit].present? && item.product.nil?
      item.status = attrs[:status] if attrs[:status].present?

      if item.save
        invalidate_groceries!
        render_success(GroceryItemSerializer.render(item))
      else
        render_error(item.errors)
      end
    rescue ArgumentError => e
      render_error({ base: [ e.message ] }, status: :unprocessable_entity)
    end

    def destroy
      grocery_item.destroy
      invalidate_groceries!
      render_success
    end

    def preview
      data = validate_params!(GenerateContract)
      start_date = parse_iso!(data[:start] || data[:start_date])
      end_date = parse_iso!(data[:end] || data[:end_date])

      render_success(grocery_list_generation(start_date: start_date, end_date: end_date).preview)
    rescue ArgumentError => e
      render_error({ base: [ e.message ] }, status: :bad_request)
    end

    def generate
      data = validate_params!(GenerateContract)
      start_date = parse_iso!(data[:start] || data[:start_date])
      end_date = parse_iso!(data[:end] || data[:end_date])

      grocery_list_generation(start_date: start_date, end_date: end_date, selection: data).generate!

      invalidate_groceries!
      render_success
    rescue ArgumentError => e
      render_error({ base: [ e.message ] }, status: :bad_request)
    end

    def from_recipe
      data = validate_params!(AddFromRecipeContract)
      recipe = @current_user.family.recipes.find(data[:recipe_id])

      RecipeGroceryListAdder.call(family: @current_user.family, recipe: recipe)

      invalidate_groceries!
      render_success(status: :created)
    rescue ArgumentError => e
      render_error({ base: [ e.message ] }, status: :unprocessable_entity)
    end

    def checkout
      ApplicationRecord.transaction do
        grocery_items.status_completed.detail.lock.each do |item|
          apply_checkout_item!(item)
          # Keep any uncovered demand visible after buying less than the recipes need.
          item.product&.pantry_entries&.reset
          suggestion = item.purchase_suggestion
          if suggestion && suggestion[:shortage] > 0
            item.update!(status: :pending, quantity_overridden: false, quantity: suggestion[:suggested_quantity])
          else
            item.destroy!
          end
        end
      end

      invalidate_groceries!
      invalidate_pantry!
      render_success
    rescue ArgumentError => e
      render_error({ base: [ e.message ] }, status: :unprocessable_entity)
    end

    private

    def grocery_items
      @current_user.family.grocery_items
    end

    def grocery_item
      grocery_items.find(params[:id])
    end

    def grocery_item_params
      validate_params!(CreateGroceryItemContract)
    end

    def grocery_item_update_params
      validate_params!(UpdateGroceryItemContract)
    end

    def parse_iso!(date_string)
      Date.iso8601(date_string)
    rescue ArgumentError
      raise ArgumentError, "Invalid date format. Use YYYY-MM-DD"
    end

    def grocery_list_generation(start_date:, end_date:, selection: {})
      GroceryListGeneration.new(
        family: @current_user.family,
        start_date: start_date,
        end_date: end_date,
        selection: selection
      )
    end

    def apply_checkout_item!(item)
      product = item.product
      return if product.nil? || product.kitchen_basic? || item.quantity.zero?

      add = PantryEntryWriter.new(
        family: @current_user.family,
        product: product
      )
      raise ArgumentError, add.errors.full_messages.to_sentence unless add.add(quantity_remaining: item.quantity)
    end

    def create_product_backed_item(attrs)
      product = @current_user.family.products.find(attrs[:product_id])
      validate_product_unit!(product, attrs[:unit])
      GroceryListEntryAdder.call(
        family: @current_user.family,
        product: product,
        quantity: attrs[:quantity],
        source: "manual"
      )
    end

    def create_custom_item(attrs)
      grocery_items.create!(
        name: attrs[:name].strip,
        aisle: attrs[:aisle],
        unit: attrs[:unit],
        quantity: attrs[:quantity],
        source: "manual",
        status: "pending"
      )
    end

    def validate_product_unit!(product, unit)
      return if unit.present? && unit.to_s == product.unit

      raise ArgumentError, "incompatible unit"
    end
  end
end
