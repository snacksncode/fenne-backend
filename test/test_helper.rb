ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module AuthHelper
  def auth_headers_for(user)
    token = user.session_tokens.first
    {"Authorization" => "Bearer #{token.token}"}
  end
end

ActiveSupport::TestCase.include AuthHelper
