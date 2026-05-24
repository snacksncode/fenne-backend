module V2Rendering
  extend ActiveSupport::Concern

  private

  def render_success(data = nil, status: :ok, meta: nil)
    body = {status: "success", data: data}
    body[:meta] = meta if meta.present?
    render json: body, status: status
  end

  def render_error(errors, status: :unprocessable_entity)
    render json: {status: "error", errors: normalize_errors(errors)}, status: status
  end

  def normalize_errors(errors)
    return errors.to_hash(true) if errors.is_a?(ActiveModel::Errors)
    return errors if errors.is_a?(Hash)

    {base: Array(errors)}
  end
end
