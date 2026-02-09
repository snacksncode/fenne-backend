class GroceryItemsController < ApplicationController
  def index
    render json: GroceryItemSerializer.render_many(grocery_items)
  end

  def show
    render json: GroceryItemSerializer.render(grocery_item)
  end

  def destroy
    grocery_item.destroy
    invalidate_groceries!
  end

  def generate
    family = @current_user.family

    start_date = parse_iso!(params.expect(:start))
    end_date = parse_iso!(params.expect(:end))

    schedule_day_ids = @current_user.family.schedule_days.in_range(start_date, end_date).pluck(:id)
    items = ScheduleItem.where(schedule_day_id: schedule_day_ids)
      .kind_recipe
      .map(&:recipe)
      .flat_map(&:ingredients)
      .group_by { |ingredient| [ingredient.name, ingredient.unit] }

    items.each do |k, ingredients|
      ingredient = ingredients.first
      total_quantity = ingredients.sum(&:quantity)
      family.grocery_items.create!(
        name: ingredient.name,
        quantity: total_quantity,
        aisle: ingredient.aisle,
        unit: ingredient.unit
      )
    end

    render json: {success: true}
  end

  def create
    item = @current_user.family.grocery_items.new(grocery_item_params)
    if item.save
      invalidate_groceries!
      return render json: GroceryItemSerializer.render(item), status: :created
    end
    render json: {error: item.errors.full_messages.first}, status: :unprocessable_content
  rescue ArgumentError => e
    render json: {error: e.message}, status: :unprocessable_entity
  end

  def update
    item = grocery_item
    if item.update(grocery_item_params)
      invalidate_groceries!
      return render json: GroceryItemSerializer.render(item), status: :ok
    end
    render json: {error: item.errors.full_messages.first}, status: :unprocessable_content
  rescue ArgumentError => e
    render json: {error: e.message}, status: :unprocessable_entity
  end

  def checkout
    grocery_items.status_completed.destroy_all
    invalidate_groceries!
  end

  private

  def parse_iso!(date_string)
    Date.iso8601(date_string)
  rescue ArgumentError
    raise ArgumentError, "Invalid date format. Use YYYY-MM-DD"
  end

  def invalidate_groceries!
    QueryInvalidator.broadcast(:grocery_items, @current_user.family)
  end

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
