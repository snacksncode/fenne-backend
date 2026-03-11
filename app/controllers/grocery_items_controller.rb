class GroceryItemsController < ApplicationController
  class GenerateContract < Dry::Validation::Contract
    params do
      required(:ingredients).filled(:hash)
    end

    rule(:ingredients) do
      value.each do |ingredient_id, count|
        key([:ingredients, ingredient_id]).failure("must be a string") unless ingredient_id.is_a?(String)
        key([:ingredients, ingredient_id]).failure("must be a positive number") unless count.is_a?(Numeric) && count > 0
      end
    end
  end

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
    system = family.imperial? ? :imperial : :metric

    start_date = parse_iso!(params.expect(:start))
    end_date = parse_iso!(params.expect(:end))
    ingredient_ids = validate_params!(GenerateContract)[:ingredients].keys

    schedule_day_ids = family.schedule_days.in_range(start_date, end_date).pluck(:id)
    grouped = ScheduleItem.where(schedule_day_id: schedule_day_ids)
      .kind_recipe
      .includes(recipe: :ingredients)
      .flat_map { |si| si.recipe&.ingredients || [] }
      .select { |ingredient| ingredient_ids.include?(ingredient.id.to_s) }
      .group_by { |i| [i.name.downcase.strip, UnitConverter.category(i.unit.to_sym)] }

    ApplicationRecord.transaction do
      grouped.each do |(_name, _category), ingredients|
        ingredient = ingredients.first
        pairs = ingredients.map { |i| UnitConverter.to_base(i.quantity.to_f, i.unit.to_sym, system) }
        total_base = pairs.sum(&:first)
        _, base_unit = pairs.first
        baked_qty, baked_unit = UnitConverter.friendly(total_base, base_unit, system)

        family.grocery_items.create!(
          name: ingredient.name,
          quantity: baked_qty,
          aisle: ingredient.aisle,
          unit: baked_unit
        )
      end
    end

    invalidate_groceries!
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

  def preview
    start_date = parse_iso!(params.expect(:start))
    end_date = parse_iso!(params.expect(:end))

    schedule_day_ids = @current_user.family.schedule_days.in_range(start_date, end_date).pluck(:id)
    items = ScheduleItem.where(schedule_day_id: schedule_day_ids)
      .kind_recipe
      .includes(recipe: :ingredients)
      .reject { |si| si.recipe.nil? }

    grouped = items.group_by(&:recipe)

    render json: PreviewRecipeSerializer.render_many(grouped, unit_preference: @current_user.family.unit_preference)
  rescue ArgumentError => e
    render json: {error: e.message}, status: :bad_request
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
