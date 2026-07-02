module V2
  class ScheduleController < ApplicationController
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

      rule do
        next if values.key?(:breakfast) ||
          values.key?(:lunch) ||
          values.key?(:dinner) ||
          values.key?(:is_shopping_day)

        base.failure("must include at least one schedule field")
      end

      %i[breakfast lunch dinner].each do |meal|
        rule(meal) do
          next if value.nil?

          if value[:type] == "recipe" && value[:recipe_id].nil?
            key([ meal, :recipe_id ]).failure("must be filled when type is recipe")
          end

          if value[:type] == "dining_out" && value[:name].nil?
            key([ meal, :name ]).failure("must be filled when type is dining_out")
          end
        end
      end
    end

    class DateRangeContract < Dry::Validation::Contract
      params do
        required(:start).filled(:string)
        required(:end).filled(:string)
      end

      rule(:start) do
        Date.iso8601(value)
      rescue ArgumentError
        key.failure("must be ISO8601 date")
      end

      rule(:end) do
        Date.iso8601(value)
      rescue ArgumentError
        key.failure("must be ISO8601 date")
      end
    end

    class DateContract < Dry::Validation::Contract
      params do
        required(:date).filled(:string)
      end

      rule(:date) do
        Date.iso8601(value)
      rescue ArgumentError
        key.failure("must be ISO8601 date")
      end
    end

    def index
      attrs = validate_params!(DateRangeContract)
      start_date = parse_iso!(attrs[:start])
      end_date = parse_iso!(attrs[:end])

      schedule_days = @current_user.family.schedule_days.in_range(start_date, end_date)
      schedule_map = schedule_days.index_by(&:date)
      schedule = (start_date..end_date).map { |date| schedule_map[date] || empty_schedule(date) }

      render_success(ScheduleDaySerializer.render_many(schedule))
    rescue ArgumentError => e
      render_error({ base: [ e.message ] }, status: :bad_request)
    end

    def create
      attrs = validate_params!(DateContract)
      date = parse_iso!(attrs[:date])
      save_schedule(date)
    rescue ArgumentError => e
      render_error({ base: [ e.message ] }, status: :bad_request)
    end

    def upsert
      attrs = validate_params!(DateContract)
      date = parse_iso!(attrs[:date])
      save_schedule(date)
    rescue ArgumentError => e
      render_error({ base: [ e.message ] }, status: :bad_request)
    end

    private

    def save_schedule(date)
      schedule_params = validate_params!(ScheduleContract)

      form = ScheduleForm.new(data: schedule_params, date: date, user: @current_user)
      if form.save
        invalidate_schedules!(dates: [ date ])
        schedule_day = @current_user.family.schedule_days.find_by(date: date)
        render_success(ScheduleDaySerializer.render(schedule_day))
      else
        render_error(form.errors)
      end
    end

    def empty_schedule(date)
      ScheduleDay.new(
        date: date,
        family: @current_user.family,
        is_shopping_day: false
      )
    end

    def parse_iso!(date_string)
      Date.iso8601(date_string)
    rescue ArgumentError
      raise ArgumentError, "Invalid date format. Use YYYY-MM-DD"
    end
  end
end
