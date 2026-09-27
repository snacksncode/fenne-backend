require "test_helper"

class V2ScheduleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john_smith)
    @date = "2026-10-01"
  end

  test "meal scheduling and clearing work without shopping days" do
    put "/v2/schedule/#{@date}", params: { lunch: { type: "dining_out", name: "Lunch out" } }, headers: auth_headers_for(@user), as: :json
    assert_response :success
    data = response.parsed_body.fetch("data")
    assert_equal "Lunch out", data.dig("lunch", "name")
    assert_not data.key?("is_shopping_day")

    put "/v2/schedule/#{@date}", params: { lunch: nil }, headers: auth_headers_for(@user), as: :json
    assert_response :success
    assert_nil response.parsed_body.dig("data", "lunch")

    get "/v2/schedule", params: { start: @date, end: "2026-10-02" }, headers: auth_headers_for(@user)
    assert_response :success
    days = response.parsed_body.fetch("data")
    assert_equal 2, days.size
    assert days.all? { |day| !day.key?("is_shopping_day") }
  end

  test "a removed shopping day field alone cannot create a schedule day" do
    assert_no_difference "ScheduleDay.count" do
      put "/v2/schedule/#{@date}", params: { is_shopping_day: true }, headers: auth_headers_for(@user), as: :json
      assert_response :unprocessable_entity
    end
  end
end
