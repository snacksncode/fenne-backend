class GroceryItemsController < ApplicationController
  def index
    render json: GroceryItemSerializer.render_many(grocery_items)
  end

  def show
    render json: GroceryItemSerializer.render(grocery_item)
  end

  def destroy
    grocery_item.destroy
    QueryInvalidator.broadcast(:grocery_items)
  end

  def generate
    family = @current_user.family

    shopping_day = family.schedule_days
      .where(is_shopping_day: true)
      .where("date >= ?", Date.today)
      .order(:date)
      .first

    recipe_ids = family
      .schedule_days
      .in_range(Date.today, shopping_day ? shopping_day.date : 2.weeks.from_now.to_date)
      .pluck(:breakfast_recipe_id, :lunch_recipe_id, :dinner_recipe_id)
      .flatten.uniq.compact

    Ingredient.where(recipe_id: recipe_ids).map do |ingredient|
      family.grocery_items.create!(
        name: ingredient.name,
        quantity: ingredient.quantity,
        aisle: ingredient.aisle,
        unit: ingredient.unit
      )
    end

    render json: ingredients
  end

  def create
    item = @current_user.family.grocery_items.new(grocery_item_params)
    if item.save
      QueryInvalidator.broadcast(:grocery_items)
      return render json: GroceryItemSerializer.render(item), status: :created
    end
    render json: {error: item.errors.full_messages.first}, status: :unprocessable_content
  rescue ArgumentError => e
    render json: {error: e.message}, status: :unprocessable_entity
  end

  def update
    item = grocery_item
    if item.update(grocery_item_params)
      QueryInvalidator.broadcast(:grocery_items)
      return render json: GroceryItemSerializer.render(item), status: :ok
    end
    render json: {error: item.errors.full_messages.first}, status: :unprocessable_content
  rescue ArgumentError => e
    render json: {error: e.message}, status: :unprocessable_entity
  end

  def checkout
    grocery_items.status_completed.destroy_all
    QueryInvalidator.broadcast(:grocery_items)
  end

  private

  def grocery_items
    @current_user.family.grocery_items
  end

  def grocery_item
    grocery_items.find(params[:id])
  end

  def grocery_item_params
    params.expect(data: [:name, :aisle, :quantity, :unit, :status])
  end
end
