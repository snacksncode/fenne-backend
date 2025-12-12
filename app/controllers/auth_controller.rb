class AuthController < ApplicationController
  skip_before_action :authenticate_request!, only: [:login, :signup]

  def login
    email, password = login_params
    user = User.find_by(email:)

    return invalid_credentials! unless user&.authenticate(password)

    render json: {
      status: :success,
      session_token: user.session_tokens.create!.token
    }
  end

  def me
    render json: {
      user: UserSerializer.render(@current_user),
      family: FamilySerializer.render(@current_user.family)
    }
  end

  def signup
    email, password, name = signup_params
    user = User.new(email:, password:, name:)

    if user.save
      return render json: {status: :success, session_token: user.session_tokens.create!.token}
    end

    render json: {error: user.errors.full_messages.first}, status: :unprocessable_content
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
    email, password = params.expect(:email, :password)
    [email.downcase, password]
  end

  def signup_params
    email, password, name = params.expect(:email, :password, :name)
    [email.downcase, password, name]
  end
end
