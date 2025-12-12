class RecipesController < ApplicationController
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
    family = @current_user.family
    form = RecipeForm.new(recipe_params.merge(family:))
    if form.save
      recipe = family.recipes.find(form.id)
      invalidate_recipe!(recipe)
      render json: RecipeSerializer.render(recipe)
    else
      render json: form.errors
    end
  end

  def update
    family = @current_user.family
    form = RecipeForm.new(recipe_params.merge(id: params[:id], family:))
    if form.save
      recipe = family.recipes.find(form.id)
      invalidate_recipe!(recipe)
      render json: RecipeSerializer.render(recipe)
    else
      render json: form.errors, status: :unprocessable_content
    end
  end

  private

  def invalidate_recipe!(recipe)
    QueryInvalidator.broadcast(:recipes)
    dates = ScheduleDay.where("breakfast_recipe_id = :id OR lunch_recipe_id = :id OR dinner_recipe_id = :id", id: recipe.id)
      .pluck(:date).group_by { |d| [d.cwyear, d.cweek] }.values.map(&:first)
      .sort_by { |d| (d - Date.today).abs }
      .map(&:to_s)
    QueryInvalidator.broadcast(:schedules, {dates:})
  end

  def recipe_params
    params.expect(data: [
      :name,
      :liked,
      :time_in_minutes,
      meal_types: [],
      ingredients: [[:name, :unit, :aisle, :quantity]]
    ])
  end
end
