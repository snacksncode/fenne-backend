module V2
  class FamilyController < ApplicationController
    class PreferencesContract < Dry::Validation::Contract
      params do
        optional(:unit_preference).filled(:string, included_in?: Family.unit_preferences.keys.map(&:to_s))
        optional(:timezone).filled(:string)
      end

      rule(:timezone) do
        key.failure("is invalid") if key? && ActiveSupport::TimeZone[value].nil?
      end
    end

    def preferences
      attrs = validate_params!(PreferencesContract)

      if @current_user.family.update(attrs)
        invalidate_family!
        render_success(FamilySerializer.render(@current_user.family))
      else
        render_error(@current_user.family.errors)
      end
    rescue ArgumentError => e
      render_error({ base: [ e.message ] }, status: :unprocessable_entity)
    end
  end
end
