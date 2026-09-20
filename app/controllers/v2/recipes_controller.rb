module V2
  class RecipesController < ApplicationController
    class BaseRecipeContract < Dry::Validation::Contract
      MEAL_TYPES = %w[breakfast lunch dinner].freeze
      UNIT_TYPES = Ingredient.units.keys.map(&:to_s)
      AISLE_TYPES = Product.aisles.keys.map(&:to_s)

      ProductSchema = Dry::Schema.Params do
        optional(:id).filled(:integer)
        optional(:name).filled(:string)
        optional(:aisle).filled(:string, included_in?: AISLE_TYPES)
        optional(:unit).filled(:string, included_in?: UNIT_TYPES)
        optional(:reminder_frequency_value).maybe(:integer, gt?: 0)
        optional(:reminder_frequency_unit).maybe(:string, included_in?: %w[days weeks months])
        optional(:is_kitchen_basic).filled(:bool)
        optional(:pack_sizes).value(:array, max_size?: 6).each(:float, gt?: 0, lteq?: 1_000_000)
        optional(:conversions).hash
      end

      IngredientSchema = Dry::Schema.Params do
        required(:quantity).filled(:float, gt?: 0)
        required(:unit).filled(:string, included_in?: UNIT_TYPES)
        optional(:name_override).maybe(:string)
        required(:product).hash(ProductSchema)
      end
    end

    class CreateRecipeContract < BaseRecipeContract
      params do
        required(:name).filled(:string)
        required(:meal_types).filled(:array, min_size?: 1).each(:string, included_in?: MEAL_TYPES)
        required(:time_in_minutes).filled(:integer, gt?: 0)
        optional(:liked).filled(:bool)
        required(:ingredients).filled(:array, min_size?: 1).each(IngredientSchema)
        optional(:notes).filled(:string)
      end

      rule(:ingredients).each do
        product = value[:product]
        unless product[:id].present?
          %i[name aisle unit].each do |field|
            key.failure("new product requires name, aisle, and unit") if product[field].blank?
          end
        end
      end
    end

    class UpdateRecipeContract < BaseRecipeContract
      params do
        optional(:name).filled(:string)
        optional(:meal_types).filled(:array, min_size?: 1).each(:string, included_in?: MEAL_TYPES)
        optional(:time_in_minutes).filled(:integer, gt?: 0)
        optional(:liked).filled(:bool)
        optional(:ingredients).filled(:array, min_size?: 1).each(IngredientSchema)
        optional(:notes).filled(:string)
      end

      rule(:ingredients).each do
        next if values[:ingredients].nil?

        product = value[:product]
        unless product[:id].present?
          %i[name aisle unit].each do |field|
            key.failure("new product requires name, aisle, and unit") if product[field].blank?
          end
        end
      end
    end

    def index
      recipes = @current_user.family.recipes.detail
      render_success(RecipeSerializer.render_many(recipes))
    end

    def show
      recipe = @current_user.family.recipes.detail.find(params[:id])
      render_success(RecipeSerializer.render(recipe))
    end

    def create
      save_recipe(contract: CreateRecipeContract)
    end

    def update
      save_recipe(id: params[:id], contract: UpdateRecipeContract)
    end

    def destroy
      recipe = @current_user.family.recipes.find(params[:id])
      recipe.destroy
      invalidate_recipe!(recipe)
      render_success
    end

    private

    def save_recipe(contract:, id: nil)
      recipe_data = validate_params!(contract)
      form = RecipeForm.new(recipe_data.merge(id: id, family: @current_user.family))
      if form.save
        recipe = @current_user.family.recipes.detail.find(form.id)
        invalidate_recipe!(recipe)
        invalidate_products! if form.touched_any_products?
        render_success(RecipeSerializer.render(recipe), status: id.present? ? :ok : :created)
      elsif form.name_collision?
        render_error(form.errors, status: :conflict)
      elsif form.missing_conversions.present?
        render_error({ missing_conversions: form.missing_conversions })
      else
        render_error(form.errors)
      end
    end

    def invalidate_recipe!(recipe)
      invalidate_recipes!
      dates = ScheduleItem.where(recipe_id: recipe.id).map(&:schedule_day)
        .pluck(:date)
        .group_by { |d| [ d.cwyear, d.cweek ] }
        .values
        .map(&:first)
        .sort_by { |d| (d - Date.today).abs }
        .map(&:to_s)

      invalidate_schedules!(dates: dates)
    end
  end
end
