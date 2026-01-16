class ApplicationController < ActionController::API
  class ValidationError < StandardError
    attr_reader :errors
    def initialize(errors)
      @errors = errors
    end
  end

  before_action :authenticate_request!
  wrap_parameters false
  rescue_from ActiveRecord::RecordNotFound, with: :not_found!

  def authenticate_request!
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

  rescue_from ValidationError do |exception|
    render json: {errors: exception.errors}, status: :unprocessable_entity
  end

  def validate_params!(contract)
    result = contract.new.call(request.parameters)
    raise ValidationError.new(result.errors.to_h) if result.failure?
    result.to_h
  end

  private

  def extract_token_from_authorization_header
    _bearer, token = request.headers["Authorization"]&.split(" ")
    token
  end
end
