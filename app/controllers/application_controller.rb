class ApplicationController < ActionController::Base
  before_action :authenticate_request!
  skip_before_action :verify_authenticity_token
  wrap_parameters false

  def authenticate_request!
    token = extract_token_from_authorization_header
    @session_token = SessionToken.find_by(token:)
    return unauthorized! unless @session_token
    return unauthorized! if @session_token.expired? && @session_token.destroy
    @current_user = @session_token.user
  end

  def unauthorized!
    render json: {error: "Unauthorized"}, status: :unauthorized
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
