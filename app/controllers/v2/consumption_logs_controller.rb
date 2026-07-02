module V2
  class ConsumptionLogsController < ApplicationController
    class CreateConsumptionLogContract < Dry::Validation::Contract
      params do
        required(:recipe_id).filled(:integer)
        required(:meal_type).filled(:string, included_in?: %w[breakfast lunch dinner])
        required(:schedule_date).filled(:string)
      end

      rule(:schedule_date) do
        Date.iso8601(value)
      rescue ArgumentError
        key.failure("must be ISO8601 date")
      end
    end

    def index
      logs = @current_user.family.consumption_logs.recent.order(:schedule_date, :meal_type)
      render_success(ConsumptionLogSerializer.render_many(logs))
    end

    def create
      attrs = validate_params!(CreateConsumptionLogContract)
      recipe = @current_user.family.recipes.detail.find(attrs[:recipe_id])
      log = nil

      ApplicationRecord.transaction do
        log = @current_user.family.consumption_logs.create!(
          recipe_name: recipe.name,
          meal_type: attrs[:meal_type],
          schedule_date: attrs[:schedule_date],
          deductions: ConsumptionDeductor.call(family: @current_user.family, recipe: recipe)
        )
        @current_user.family.consumption_logs.stale.destroy_all
      end

      invalidate_consumption!
      render_success(ConsumptionLogSerializer.render(log), status: :created)
    rescue ActiveRecord::RecordNotUnique
      render_error({ base: [ "slot already filled" ] }, status: :conflict)
    rescue ArgumentError => e
      render_error({ base: [ e.message ] }, status: :bad_request)
    rescue ActiveRecord::RecordInvalid => e
      render_error(e.record.errors)
    end

    def destroy
      log = @current_user.family.consumption_logs.find(params[:id])

      warning = nil
      ApplicationRecord.transaction do
        log.restore_pantry!
        warning = "Some pantry quantities could not be restored" if log.partial_restore_failed?
        log.destroy!
      end

      invalidate_consumption!
      render_success(nil, meta: warning ? { warning: warning } : nil)
    end
  end
end
