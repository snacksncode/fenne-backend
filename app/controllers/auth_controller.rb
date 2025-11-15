class AuthController < ApplicationController
  skip_before_action :authenticate_request!, only: [:login]

  def login
    email, password = login_params
    user = User.find_by(email:)

    return invalid_credentials! unless user&.authenticate(password)

    render json: {
      status: :success,
      session_token: user.session_tokens.create!.token
    }
  end

  def logout
    @session_token.destroy!
    render json: {status: :success}
  end

  private

  def invalid_credentials!
    error = "Invalid credentials, please double check them"
    render json: {status: :error, error:}, status: :unauthorized
  end

  def login_params
    params.expect(:email, :password)
  end
end
