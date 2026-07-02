require "test_helper"

class V2EnvelopeTest < ActionDispatch::IntegrationTest
  test "v2 not found errors use v2 envelope" do
    user = users(:john_smith)

    get "/v2/products/999999", headers: auth_headers_for(user)

    assert_response :not_found
    assert_equal "error", response.parsed_body["status"]
    assert_equal ["Not found"], response.parsed_body.dig("errors", "base")
  end

  test "v2 unauthorized errors use v2 envelope" do
    get "/v2/products"

    assert_response :unauthorized
    assert_equal "error", response.parsed_body["status"]
  end
end
