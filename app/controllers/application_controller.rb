class ApplicationController < ActionController::Base
  before_action :authenticate_request!
  skip_before_action :verify_authenticity_token
  wrap_parameters false
  rescue_from ActiveRecord::RecordNotFound, with: :not_found!

  def authenticate_request!
    # sleep(rand(0.2..0.8))
    token = extract_token_from_authorization_header
    @session_token = SessionToken.find_by(token:)
    return unauthorized! unless @session_token
    return unauthorized! if @session_token.expired? && @session_token.destroy
    @session_token.refresh! if @session_token.needs_refresh?
    @current_user = @session_token.user
  end

  def unauthorized!
    render json: {error: "Unauthorized"}, status: :unauthorized
  end

  def bad_request!(message = "Bad request")
    render json: {error: message}, status: :bad_request
  end

  def not_found!
    render json: {error: "Not found"}, status: :not_found
  end

  rescue_from ActionController::ParameterMissing do |exception|
    render json: {error: exception.message}, status: :bad_request
  end

  private

  def extract_token_from_authorization_header
    _bearer, token = request.headers["Authorization"]&.split(" ")
    token
  end
end
