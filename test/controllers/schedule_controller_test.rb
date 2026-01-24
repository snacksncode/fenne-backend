require "test_helper"

class ScheduleControllerTest < ActionDispatch::IntegrationTest
  # GET /schedule
  test "index returns schedule for date range" do
    user = users(:john_smith)
    start_date = Date.tomorrow
    end_date = Date.tomorrow + 5.days

    get "/schedule", params: {start: start_date.to_s, end: end_date.to_s}, headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert json.is_a?(Array)
    assert_equal 6, json.length # 6 days inclusive
  end

  test "index includes empty schedule days" do
    user = users(:john_smith)
    start_date = Date.today + 50.days
    end_date = Date.today + 52.days

    get "/schedule", params: {start: start_date.to_s, end: end_date.to_s}, headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert_equal 3, json.length
    json.each do |day|
      assert_equal false, day["is_shopping_day"]
    end
  end

  test "index returns 400 for invalid date format" do
    user = users(:john_smith)

    get "/schedule", params: {start: "invalid", end: "2024-01-01"}, headers: auth_headers_for(user)

    assert_response :bad_request
    json = response.parsed_body
    assert_includes json["error"], "Invalid date format"
  end

  test "index requires authentication" do
    get "/schedule", params: {start: Date.today.to_s, end: Date.tomorrow.to_s}

    assert_response :unauthorized
  end

  # PUT /schedule/:date
  test "upsert creates schedule day with meals" do
    user = users(:john_smith)
    date = Date.today + 60.days
    recipe = recipes(:pasta_carbonara_smith)

    put "/schedule/#{date}",
        params: {
          breakfast: {type: "recipe", recipe_id: recipe.id.to_s},
          lunch: {type: "dining_out", name: "Restaurant"},
          is_shopping_day: true
        },
        headers: auth_headers_for(user),
        as: :json

    assert_response :ok
    json = response.parsed_body
    assert_equal date.to_s, json["date"]
    assert_equal true, json["is_shopping_day"]
    assert_not_nil json["breakfast"]
    assert_not_nil json["lunch"]
  end

  test "upsert updates existing schedule day" do
    user = users(:john_smith)
    schedule_day = schedule_days(:tomorrow)
    recipe = recipes(:pasta_carbonara_smith)

    put "/schedule/#{schedule_day.date}",
        params: {
          dinner: {type: "recipe", recipe_id: recipe.id.to_s},
          is_shopping_day: false
        },
        headers: auth_headers_for(user),
        as: :json

    assert_response :ok
    json = response.parsed_body
    assert_not_nil json["dinner"]
  end

  test "upsert validates recipe existence" do
    user = users(:john_smith)
    date = Date.today + 70.days

    put "/schedule/#{date}",
        params: {
          breakfast: {type: "recipe", recipe_id: "999999"}
        },
        headers: auth_headers_for(user),
        as: :json

    assert_response :unprocessable_entity
  end

  test "upsert validates recipe_id required when type is recipe" do
    user = users(:john_smith)
    date = Date.today + 80.days

    put "/schedule/#{date}",
        params: {
          breakfast: {type: "recipe"}
        },
        headers: auth_headers_for(user),
        as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_not_nil json["errors"]
  end

  test "upsert validates name required when type is dining_out" do
    user = users(:john_smith)
    date = Date.today + 90.days

    put "/schedule/#{date}",
        params: {
          lunch: {type: "dining_out"}
        },
        headers: auth_headers_for(user),
        as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_not_nil json["errors"]
  end

  test "upsert handles all three meal types" do
    user = users(:john_smith)
    date = Date.today + 100.days
    recipe = recipes(:pasta_carbonara_smith)

    put "/schedule/#{date}",
        params: {
          breakfast: {type: "recipe", recipe_id: recipe.id.to_s},
          lunch: {type: "dining_out", name: "Cafe"},
          dinner: {type: "recipe", recipe_id: recipe.id.to_s},
          is_shopping_day: true
        },
        headers: auth_headers_for(user),
        as: :json

    assert_response :ok
    json = response.parsed_body
    assert_not_nil json["breakfast"]
    assert_not_nil json["lunch"]
    assert_not_nil json["dinner"]
  end

  test "upsert returns 400 for invalid date format" do
    user = users(:john_smith)

    put "/schedule/invalid-date",
        params: {breakfast: {type: "dining_out", name: "Test"}},
        headers: auth_headers_for(user),
        as: :json

    assert_response :bad_request
  end

  test "upsert requires authentication" do
    put "/schedule/#{Date.today}",
        params: {breakfast: {type: "dining_out", name: "Test"}},
        as: :json

    assert_response :unauthorized
  end
end
