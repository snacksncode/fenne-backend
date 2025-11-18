class GroceryItemsController < ApplicationController
  def index
    render json: grocery_items
  end

  def show
    render json: grocery_item
  end

  def destroy
    grocery_item.destroy
  end

  def create
    item = @current_user.family.grocery_items.new(grocery_item_params)
    return render json: item, status: :created if item.save
    render json: {error: item.errors.full_messages.first}, status: :unprocessable_content
  rescue ArgumentError => e
    render json: {error: e.message}, status: :unprocessable_entity
  end

  def update
    item = grocery_item
    return render json: item, status: :ok if item.update(grocery_item_params)
    render json: {error: item.errors.full_messages.first}, status: :unprocessable_content
  rescue ArgumentError => e
    render json: {error: e.message}, status: :unprocessable_entity
  end

  private

  def grocery_items
    @current_user.family.grocery_items
  end

  def grocery_item
    grocery_items.find(params[:id])
  end

  def grocery_item_params
    params.expect(data: [:name, :aisle, :quantity, :unit])
  end
end
