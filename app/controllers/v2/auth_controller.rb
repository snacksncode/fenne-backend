module V2
  class AuthController < ApplicationController
    skip_before_action :authenticate_request!, only: [ :login, :signup, :guest ]

    class LoginContract < Dry::Validation::Contract
      params do
        required(:email).filled(:string)
        required(:password).filled(:string)
      end

      rule(:email) do
        key.failure("format invalid") unless URI::MailTo::EMAIL_REGEXP.match?(value)
      end
    end

    class SignupContract < Dry::Validation::Contract
      params do
        required(:email).filled(:string)
        required(:password).filled(:string)
        required(:name).filled(:string)
      end

      rule(:email) do
        key.failure("format invalid") unless URI::MailTo::EMAIL_REGEXP.match?(value)
      end
    end

    class PasswordContract < Dry::Validation::Contract
      params do
        required(:current_password).filled(:string)
        required(:new_password).filled(:string)
      end
    end

    class ChangeDetailsContract < Dry::Validation::Contract
      params do
        optional(:name).filled(:string)
        optional(:email).filled(:string)
      end

      rule(:email) do
        key.failure("format invalid") if key? && !URI::MailTo::EMAIL_REGEXP.match?(value)
      end
    end

    def me
      render_success({
        user: UserSerializer.render(@current_user),
        family: FamilySerializer.render(@current_user.family)
      })
    end

    def login
      email, password = login_params
      user = User.find_by(email: email)
      return invalid_credentials! unless user&.authenticate(password)

      render_success({ session_token: user.session_tokens.create!.token })
    end

    def signup
      email, password, name = signup_params
      user = User.new(email: email, password: password, name: name)

      if user.save
        render_success({ session_token: user.session_tokens.create!.token }, status: :created)
      else
        render_error(user.errors)
      end
    end

    def guest
      email = "#{SecureRandom.uuid}+guest@fenneplanner.com"
      password = SecureRandom.hex(16)
      user = User.new(email: email, password: password, name: "Guest")

      if user.save
        render_success({ session_token: user.session_tokens.create!.token }, status: :created)
      else
        render_error(user.errors)
      end
    end

    def logout
      @session_token.destroy!
      render_success
    end

    def change_password
      current_password, new_password = password_params
      return invalid_credentials! unless @current_user.authenticate(current_password)

      @current_user.update!(password: new_password)
      render_success
    end

    def change_details
      data = change_details_params
      @current_user.update!(name: data[:name]) if data[:name].present?
      @current_user.update!(email: data[:email]) if data[:email].present?
      render_success(UserSerializer.render(@current_user))
    end

    def convert_guest
      email, password, name = signup_params
      if @current_user.update(email: email, password: password, name: name)
        render_success(UserSerializer.render(@current_user))
      else
        render_error(@current_user.errors)
      end
    end

    def destroy
      @current_user.destroy!
      render_success
    end

    private

    def invalid_credentials!
      render_error({ base: [ "Invalid credentials, please double check them" ] }, status: :unauthorized)
    end

    def login_params
      attrs = validate_params!(LoginContract)
      [ attrs[:email].downcase, attrs[:password] ]
    end

    def signup_params
      attrs = validate_params!(SignupContract)
      [ attrs[:email].downcase, attrs[:password], attrs[:name] ]
    end

    def password_params
      attrs = validate_params!(PasswordContract)
      [ attrs[:current_password], attrs[:new_password] ]
    end

    def change_details_params
      validate_params!(ChangeDetailsContract)
    end
  end
end
