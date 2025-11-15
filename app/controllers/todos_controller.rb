class TodosController < ApplicationController
  def index
    render json: Todo.all
  end

  def create
    attributes = create_params.merge(is_completed: false)
    @todo = Todo.new(attributes)

    if @todo.save
      render json: @todo, status: :created
      return
    end

    render json: @todo.errors, status: :unprocessable_content
  end

  def update
    Todo.find(params[:id]).update(update_params)
  end

  def destroy
    Todo.find(params[:id]).destroy
  end

  private

  def create_params
    params.expect(todo: [:content])
  end

  def update_params
    params.expect(todo: [:content, :is_completed])
  end
end
