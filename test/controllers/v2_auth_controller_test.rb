require "test_helper"

class V2AuthControllerTest < ActionDispatch::IntegrationTest
  test "details change saves all supplied fields and returns the user" do
    user = users(:john_smith)

    post "/v2/change_details", params: { name: "John Updated", email: "updated@example.com" },
      headers: auth_headers_for(user), as: :json

    assert_response :success
    assert_equal "success", response.parsed_body["status"]
    assert_equal "John Updated", response.parsed_body.dig("data", "name")
    assert_equal "updated@example.com", user.reload.email
  end

  test "details change preserves omitted fields" do
    user = users(:john_smith)
    original_email = user.email

    post "/v2/change_details", params: { name: "John Updated" },
      headers: auth_headers_for(user), as: :json

    assert_response :success
    assert_equal "John Updated", user.reload.name
    assert_equal original_email, user.email
  end

  test "invalid email change returns errors without saving the supplied name" do
    user = users(:john_smith)
    original_details = user.attributes.slice("name", "email")

    post "/v2/change_details", params: { name: "Do not save", email: users(:jane_smith).email },
      headers: auth_headers_for(user), as: :json

    assert_response :unprocessable_entity
    assert_equal "error", response.parsed_body["status"]
    assert response.parsed_body.dig("errors", "email").present?
    assert_equal original_details, user.reload.attributes.slice("name", "email")
  end

  test "details change requires authentication" do
    post "/v2/change_details", params: { name: "Nobody" }, as: :json

    assert_response :unauthorized
    assert_equal "error", response.parsed_body["status"]
  end

  test "malformed email leaves profile details unchanged" do
    user = users(:john_smith)
    original_details = user.attributes.slice("name", "email")

    post "/v2/change_details", params: { name: "Do not save", email: "invalid-email" },
      headers: auth_headers_for(user), as: :json

    assert_response :unprocessable_entity
    assert_equal "error", response.parsed_body["status"]
    assert_equal [ "format invalid" ], response.parsed_body.dig("errors", "email")
    assert_equal original_details, user.reload.attributes.slice("name", "email")
  end

  test "signup and guest conversion reject malformed emails through their contracts" do
    user = users(:guest_user)
    original_details = user.attributes.slice("name", "email", "password_digest")

    [ "/v2/signup", "/v2/convert_guest" ].each do |path|
      assert_no_difference("User.count") do
        post path, params: { name: "Do not save", email: "invalid-email", password: "newpassword" },
          headers: auth_headers_for(user), as: :json
      end

      assert_response :unprocessable_entity
      assert_equal "error", response.parsed_body["status"]
      assert_equal [ "format invalid" ], response.parsed_body.dig("errors", "email")
      assert_equal original_details, user.reload.attributes.slice("name", "email", "password_digest")
    end
  end
end
