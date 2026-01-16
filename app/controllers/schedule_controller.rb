class ScheduleController < ApplicationController
  rescue_from ArgumentError, with: :bad_request

  class ScheduleContract < Dry::Validation::Contract
    MealSchema = Dry::Schema.Params do
      required(:type).filled(:string, included_in?: %w[recipe dining_out])
      optional(:recipe_id).maybe(:string)
      optional(:name).maybe(:string)
    end

    params do
      optional(:breakfast).maybe(MealSchema)
      optional(:lunch).maybe(MealSchema)
      optional(:dinner).maybe(MealSchema)
      optional(:is_shopping_day).filled(:bool)
    end

    %i[breakfast lunch dinner].each do |meal|
      rule(meal) do
        next if value.nil?

        if value[:type] == "recipe" && value[:recipe_id].nil?
          key([meal, :recipe_id]).failure("must be filled when type is recipe")
        end

        if value[:type] == "dining_out" && value[:name].nil?
          key([meal, :name]).failure("must be filled when type is dining_out")
        end
      end
    end
  end

  def index
    start_date = parse_iso!(params[:start])
    end_date = parse_iso!(params[:end])

    schedule_days = @current_user.family.schedule_days.in_range(start_date, end_date)
    schedule_map = schedule_days.index_by(&:date)

    schedule = (start_date..end_date).map do |date|
      schedule_map[date] || empty_schedule(date)
    end

    render json: ScheduleDaySerializer.render_many(schedule)
  end

  def upsert
    date = parse_iso!(params[:date])
    schedule_params = validate_params!(ScheduleContract)

    # TODO: probably we should params.expect(:data) instead of using raw params
    form = ScheduleForm.new(data: schedule_params, date: date, user: @current_user)
    if form.save
      QueryInvalidator.broadcast(:schedules, @current_user.family, {dates: [date]})
      schedule_day = @current_user.family.schedule_days.find_by(date:)
      render json: ScheduleDaySerializer.render(schedule_day), status: :ok
    else
      render json: {errors: form.errors}, status: :unprocessable_entity
    end
  end

  private

  def empty_schedule(date)
    ScheduleDay.new(
      date:,
      family: @current_user.family,
      is_shopping_day: false
    )
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
