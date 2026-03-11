require "test_helper"

class FamilyControllerTest < ActionDispatch::IntegrationTest
  # PATCH /family/preferences
  test "preferences updates unit_preference to imperial" do
    user = users(:john_smith)
    assert_equal "metric", user.family.unit_preference

    patch "/family/preferences",
      params: { data: { unit_preference: "imperial" } },
      headers: auth_headers_for(user),
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal true, json["success"]
    user.reload
    assert_equal "imperial", user.family.unit_preference
  end

  test "preferences updates unit_preference to metric" do
    user = users(:john_smith)
    user.family.update!(unit_preference: :imperial)

    patch "/family/preferences",
      params: { data: { unit_preference: "metric" } },
      headers: auth_headers_for(user),
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal true, json["success"]
    user.reload
    assert_equal "metric", user.family.unit_preference
  end

  test "preferences updates affect all family members" do
    user1 = users(:john_smith)
    user2 = users(:jane_smith)
    assert_equal user1.family.id, user2.family.id

    patch "/family/preferences",
      params: { data: { unit_preference: "imperial" } },
      headers: auth_headers_for(user1),
      as: :json

    assert_response :success
    user1.reload
    user2.reload
    assert_equal "imperial", user1.family.unit_preference
    assert_equal "imperial", user2.family.unit_preference
  end

  test "preferences requires authentication" do
    patch "/family/preferences",
      params: { data: { unit_preference: "imperial" } },
      as: :json

    assert_response :unauthorized
  end

  test "preferences rejects invalid unit_preference value" do
    user = users(:john_smith)

    patch "/family/preferences",
      params: { data: { unit_preference: "invalid" } },
      headers: auth_headers_for(user),
      as: :json

    assert_response :unprocessable_content
    json = response.parsed_body
    assert_not_nil json["error"]
  end
end
