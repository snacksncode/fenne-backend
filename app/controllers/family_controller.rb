class FamilyController < ApplicationController
  def preferences
    if @current_user.family.update(preferences_params)
      render json: { success: true }
    else
      render json: { error: @current_user.family.errors.full_messages.first }, status: :unprocessable_content
    end
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def preferences_params
    params.expect(data: [ :unit_preference ])
  end
end
