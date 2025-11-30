class ScheduleController < ApplicationController
  rescue_from ArgumentError, with: :bad_request

  def index
    start_date = parse_iso!(params[:start])
    end_date = parse_iso!(params[:end])

    schedule_days = @current_user.family.schedule_days
      .includes(breakfast_recipe: :ingredients, lunch_recipe: :ingredients, dinner_recipe: :ingredients)
      .in_range(start_date, end_date)

    schedule_map = schedule_days.index_by(&:date)

    schedule = (start_date..end_date).map do |date|
      schedule_map[date] || empty_schedule(date)
    end

    render json: ScheduleDaySerializer.render_many(schedule)
  end

  def upsert
    date = parse_iso!(params[:date])
    schedule_day = @current_user.family.schedule_days.find_or_create_by(date:)

    if schedule_day.update(schedule_day_params)
      QueryInvalidator.broadcast(:schedules, {date:})
      render json: ScheduleDaySerializer.render(schedule_day), status: :ok
    else
      render json: schedule_day.errors, status: :unprocessable_content
    end
  end

  private

  def empty_schedule(date)
    ScheduleDay.new(
      date:,
      family: @current_user.family,
      breakfast_recipe_id: nil,
      lunch_recipe_id: nil,
      dinner_recipe_id: nil,
      is_shopping_day: false
    )
  end

  def schedule_day_params
    params.expect(data: [
      :date,
      :breakfast_recipe_id,
      :lunch_recipe_id,
      :dinner_recipe_id,
      :is_shopping_day
    ])
  end

  def parse_iso!(date_string)
    Date.iso8601(date_string)
  rescue ArgumentError
    raise ArgumentError, "Invalid date format. Use YYYY-MM-DD"
  end

  def bad_request(exception)
    render json: {error: exception.message}, status: :bad_request
  end
end
