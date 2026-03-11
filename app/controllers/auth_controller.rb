class AuthController < ApplicationController
  skip_before_action :authenticate_request!, only: [:login, :signup, :guest]

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

  def change_password
    current_password, new_password = password_params
    return invalid_credentials! unless @current_user.authenticate(current_password)
    @current_user.update!(password: new_password)
    render json: {success: true}
  end

  def change_details
    data = change_details_params
    @current_user.update!(name: data[:name]) if data[:name].present?
    @current_user.update!(email: data[:email]) if data[:email].present?
    render json: {success: true}
  end

  def convert_guest
    email, password, name = signup_params
    attrs = {email:, password:, name:}
    if @current_user.update(attrs)
      return render json: {status: :success}
    end

    render json: {error: @current_user.errors.full_messages.first}, status: :unprocessable_content
  end

  def signup
    email, password, name = signup_params
    user = User.new(email:, password:, name:)

    if user.save
      return render json: {status: :success, session_token: user.session_tokens.create!.token}
    end

    render json: {error: user.errors.full_messages.first}, status: :unprocessable_content
  end

  def destroy
    @current_user.destroy!
  end

  def guest
    email = "#{SecureRandom.uuid}+guest@fenneplanner.com"
    password = SecureRandom.hex(16)
    user = User.new(email:, password:, name: "Guest")

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
    validate_email!(email)
    [email.downcase, password]
  end

  def signup_params
    email, password, name = params.expect(:email, :password, :name)
    validate_email!(email)
    [email.downcase, password, name]
  end

  def password_params
    params.expect(:current_password, :new_password)
  end

  def change_details_params
    data = params.expect(data: [:name, :email])
    validate_email!(data[:email]) if data[:email].present?
    data
  end
end
