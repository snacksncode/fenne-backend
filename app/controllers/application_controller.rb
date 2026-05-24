class ApplicationController < ActionController::API
  include QueryInvalidation
  include V2Rendering

  class ValidationError < StandardError
    attr_reader :errors
    def initialize(errors)
      @errors = errors
    end
  end

  class InvalidEmailError < StandardError; end

  before_action :authenticate_request!
  wrap_parameters false
  rescue_from ActiveRecord::RecordNotFound, with: :not_found!
  rescue_from ActiveRecord::RecordNotUnique, with: :conflict!
  rescue_from InvalidEmailError, with: :invalid_email!
  rescue_from ActionController::ParameterMissing, with: :parameter_missing!
  rescue_from ValidationError, with: :validation_error!

  def authenticate_request!
    token = extract_token_from_authorization_header
    @session_token = SessionToken.find_by(token:)
    return unauthorized! unless @session_token
    return unauthorized! if @session_token.expired? && @session_token.destroy
    @session_token.refresh! if @session_token.needs_refresh?
    @current_user = @session_token.user
  end

  def unauthorized!
    return render_error({base: ["Unauthorized"]}, status: :unauthorized) if v2_request?

    render json: {error: "Unauthorized"}, status: :unauthorized
  end

  def bad_request!(message = "Bad request")
    return render_error({base: [message]}, status: :bad_request) if v2_request?

    render json: {error: message}, status: :bad_request
  end

  def unprocessable_entity!(errors)
    return render_error(errors) if v2_request?

    render json: {errors: errors}, status: :unprocessable_entity
  end

  def validate_email!(email)
    is_valid = email.to_s.match?(URI::MailTo::EMAIL_REGEXP)
    raise InvalidEmailError unless is_valid
  end

  def not_found!
    return render_error({base: ["Not found"]}, status: :not_found) if v2_request?

    render json: {error: "Not found"}, status: :not_found
  end

  def conflict!
    return render_error({base: ["conflict"]}, status: :conflict) if v2_request?

    render json: {error: "Conflict"}, status: :conflict
  end

  def invalid_email!
    bad_request!("Email format invalid")
  end

  def parameter_missing!(exception)
    bad_request!(exception.message)
  end

  def validation_error!(exception)
    unprocessable_entity!(exception.errors)
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

  def v2_request?
    request.path.start_with?("/v2")
  end
end
