require "test_helper"

class AuthControllerTest < ActionDispatch::IntegrationTest
  # POST /signup
  test "signup creates user and returns session token" do
    assert_difference("User.count", 1) do
      post "/signup", params: {email: "newuser@example.com", password: "password123", name: "New User"}, as: :json
    end

    assert_response :success
    json = response.parsed_body
    assert_equal "success", json["status"]
    assert_not_nil json["session_token"]
  end

  test "signup returns error for duplicate email" do
    existing_user = users(:john_smith)

    assert_no_difference("User.count") do
      post "/signup", params: {email: existing_user.email, password: "password123", name: "Test"}, as: :json
    end

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_includes json["error"], "Email has already been taken"
  end

  test "signup downcases email" do
    post "/signup", params: {email: "MixedCase@Example.COM", password: "password123", name: "Test"}, as: :json

    assert_response :success
    user = User.find_by(email: "mixedcase@example.com")
    assert_not_nil user
  end

  # POST /login
  test "login returns session token with valid credentials" do
    user = users(:john_smith)

    post "/login", params: {email: user.email, password: "test1234"}, as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal "success", json["status"]
    assert_not_nil json["session_token"]
  end

  test "login returns 401 with invalid password" do
    user = users(:john_smith)

    post "/login", params: {email: user.email, password: "wrongpassword"}, as: :json

    assert_response :unauthorized
    json = response.parsed_body
    assert_equal "error", json["status"]
    assert_includes json["error"], "Invalid credentials"
  end

  test "login returns 401 with non-existent email" do
    post "/login", params: {email: "nonexistent@example.com", password: "password123"}, as: :json

    assert_response :unauthorized
    json = response.parsed_body
    assert_equal "error", json["status"]
  end

  test "login downcases email" do
    user = users(:john_smith)

    post "/login", params: {email: user.email.upcase, password: "test1234"}, as: :json

    assert_response :success
  end

  # POST /guest
  test "guest creates user with random email" do
    assert_difference("User.count", 1) do
      post "/guest", as: :json
    end

    assert_response :success
    json = response.parsed_body
    assert_equal "success", json["status"]
    assert_not_nil json["session_token"]

    user = User.last
    assert_includes user.email, "@fenneplanner.com"
    assert_equal "Guest", user.name
  end

  # POST /logout
  test "logout destroys session token" do
    user = users(:john_smith)
    token = user.session_tokens.first

    post "/logout", headers: auth_headers_for(user)

    assert_response :success
    assert_not SessionToken.exists?(token.id)
  end

  test "logout requires authentication" do
    post "/logout"

    assert_response :unauthorized
  end

  # GET /me
  test "me returns current user and family" do
    user = users(:john_smith)

    get "/me", headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert_not_nil json["user"]
    assert_not_nil json["family"]
    assert_equal user.id.to_s, json["user"]["id"]
    assert_equal user.family.id.to_s, json["family"]["id"]
  end

  test "me requires authentication" do
    get "/me"

    assert_response :unauthorized
  end

  # POST /change_details
  test "change_details updates name" do
    user = users(:john_smith)
    new_name = "Updated Name"

    post "/change_details",
      params: {data: {name: new_name}},
      headers: auth_headers_for(user),
      as: :json

    assert_response :success
    user.reload
    assert_equal new_name, user.name
  end

  test "change_details updates email" do
    user = users(:john_smith)
    new_email = "newemail@example.com"

    post "/change_details",
      params: {data: {email: new_email}},
      headers: auth_headers_for(user),
      as: :json

    assert_response :success
    user.reload
    assert_equal new_email, user.email
  end





  test "change_details updates multiple fields at once" do
    user = users(:john_smith)
    new_name = "Updated Name"
    new_email = "newemail@example.com"

    post "/change_details",
      params: {data: {name: new_name, email: new_email}},
      headers: auth_headers_for(user),
      as: :json

    assert_response :success
    user.reload
    assert_equal new_name, user.name
    assert_equal new_email, user.email
  end

  test "me endpoint includes unit_preference in response" do
    user = users(:john_smith)
    user.family.update!(unit_preference: 1)

    get "/me", headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert_not_nil json["family"]
    assert_equal 1, json["family"]["unit_preference"]
  end

  test "change_details requires authentication" do
    post "/change_details",
      params: {data: {name: "Test"}},
      as: :json

    assert_response :unauthorized
  end
  # POST /change_password
  test "change_password updates password" do
    user = users(:john_smith)

    post "/change_password",
      params: {current_password: "test1234", new_password: "newpassword123"},
      headers: auth_headers_for(user),
      as: :json

    assert_response :success
    user.reload
    assert user.authenticate("newpassword123")
    assert_not user.authenticate("test1234")
  end

  test "change_password requires correct current password" do
    user = users(:john_smith)

    post "/change_password",
      params: {current_password: "wrongpassword", new_password: "newpassword123"},
      headers: auth_headers_for(user),
      as: :json

    assert_response :unauthorized
    json = response.parsed_body
    assert_includes json["error"], "Invalid credentials"
  end

  test "change_password requires authentication" do
    post "/change_password",
      params: {current_password: "test1234", new_password: "newpassword123"},
      as: :json

    assert_response :unauthorized
  end

  # POST /convert_guest

end
