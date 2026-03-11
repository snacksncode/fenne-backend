require "test_helper"

class FamilyControllerTest < ActionDispatch::IntegrationTest
  # PATCH /family/preferences
  test "preferences updates unit_preference to 1 (imperial)" do
    user = users(:john_smith)
    assert_equal 0, user.family.unit_preference

    patch "/family/preferences",
      params: { data: { unit_preference: 1 } },
      headers: auth_headers_for(user),
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal true, json["success"]
    user.reload
    assert_equal 1, user.family.unit_preference
  end

  test "preferences updates unit_preference to 0 (metric)" do
    user = users(:john_smith)
    user.family.update!(unit_preference: 1)

    patch "/family/preferences",
      params: { data: { unit_preference: 0 } },
      headers: auth_headers_for(user),
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal true, json["success"]
    user.reload
    assert_equal 0, user.family.unit_preference
  end

  test "preferences updates affect all family members" do
    user1 = users(:john_smith)
    user2 = users(:jane_smith)
    assert_equal user1.family.id, user2.family.id

    patch "/family/preferences",
      params: { data: { unit_preference: 1 } },
      headers: auth_headers_for(user1),
      as: :json

    assert_response :success
    user1.reload
    user2.reload
    assert_equal 1, user1.family.unit_preference
    assert_equal 1, user2.family.unit_preference
  end

  test "preferences requires authentication" do
    patch "/family/preferences",
      params: { data: { unit_preference: 1 } },
      as: :json

    assert_response :unauthorized
  end

  test "preferences rejects invalid unit_preference value" do
    user = users(:john_smith)

    patch "/family/preferences",
      params: { data: { unit_preference: 99 } },
      headers: auth_headers_for(user),
      as: :json

    assert_response :unprocessable_content
    json = response.parsed_body
    assert_not_nil json["error"]
  end
end
