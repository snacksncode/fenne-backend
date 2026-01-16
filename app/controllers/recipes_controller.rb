class RecipesController < ApplicationController
  class RecipeContract < Dry::Validation::Contract
    MEAL_TYPES = %w[breakfast lunch dinner]
    UNIT_TYPES = %w[g kg ml l fl_oz cup tbsp tsp pt qt oz lb count]
    AISLE_TYPES = %w[produce bakery dairy_eggs meat seafood pantry frozen_foods beverages snacks condiments_sauces spices_baking household personal_care pet_supplies other]

    IngredientSchema = Dry::Schema.Params do
      required(:name).filled(:string)
      required(:quantity).filled(:float, gt?: 0)
      required(:unit).filled(:string, included_in?: UNIT_TYPES)
      required(:aisle).filled(:string, included_in?: AISLE_TYPES)
    end

    params do
      required(:data).schema do
        optional(:name).filled(:string)
        optional(:meal_types).filled(:array, min_size?: 1).each(:string, included_in?: MEAL_TYPES)
        optional(:time_in_minutes).filled(:integer, gt?: 0)
        optional(:liked).filled(:bool)
        optional(:ingredients).filled(:array, min_size?: 1).each(IngredientSchema)
      end
    end
  end

  def index
    recipes = @current_user.family.recipes.includes(:ingredients)
    render json: RecipeSerializer.render_many(recipes)
  end

  def show
    recipe = @current_user.family.recipes.includes(:ingredients).find(params[:id])
    render json: RecipeSerializer.render(recipe)
  end

  def destroy
    recipe = @current_user.family.recipes.find(params[:id])
    invalidate_recipe!(recipe)
    recipe.destroy
  end

  def create
    recipe_data = validate_params!(RecipeContract)[:data]
    form = RecipeForm.new(recipe_data.merge(family: @current_user.family))
    if form.save
      recipe = @current_user.family.recipes.find(form.id)
      invalidate_recipe!(recipe)
      render json: RecipeSerializer.render(recipe)
    else
      render json: form.errors, status: :unprocessable_content
    end
  end

  def update
    recipe_data = validate_params!(RecipeContract)[:data]
    form = RecipeForm.new(recipe_data.merge(id: params[:id], family: @current_user.family))
    if form.save
      recipe = @current_user.family.recipes.find(form.id)
      invalidate_recipe!(recipe)
      render json: RecipeSerializer.render(recipe)
    else
      render json: form.errors, status: :unprocessable_content
    end
  end

  private

  def invalidate_recipe!(recipe)
    QueryInvalidator.broadcast(:recipes, @current_user.family)
    dates = ScheduleItem.where(recipe_id: recipe.id).map(&:schedule_day)
      .pluck(:date)
      .group_by { |d| [d.cwyear, d.cweek] }
      .values
      .map(&:first)
      .sort_by { |d| (d - Date.today).abs }
      .map(&:to_s)

    QueryInvalidator.broadcast(:schedules, @current_user.family, {dates:})
  end
end
