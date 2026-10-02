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

  test "partial changes preserve other meals and validate every submitted recipe through the Family" do
    put "/v2/schedule/#{@date}", params: {
      breakfast: { type: "recipe", recipe_id: recipes(:scrambled_eggs_smith).id.to_s },
      lunch: { type: "dining_out", name: "Lunch out" }
    }, headers: auth_headers_for(@user), as: :json
    assert_response :success

    put "/v2/schedule/#{@date}", params: { lunch: nil }, headers: auth_headers_for(@user), as: :json
    assert_response :success
    assert_not_nil response.parsed_body.dig("data", "breakfast")
    assert_nil response.parsed_body.dig("data", "lunch")

    other_recipe = families(:johnson_family).recipes.create!(name: "Other dinner", meal_types: [ :dinner ], time_in_minutes: 10)
    put "/v2/schedule/#{@date}", params: {
      breakfast: { type: "recipe", recipe_id: other_recipe.id.to_s },
      lunch: { type: "recipe", recipe_id: other_recipe.id.to_s },
      dinner: { type: "recipe", recipe_id: other_recipe.id.to_s }
    }, headers: auth_headers_for(@user), as: :json
    assert_response :unprocessable_entity
    %w[breakfast lunch dinner].each do |meal_type|
      assert_equal [ "#{meal_type.capitalize} recipe does not exist" ], response.parsed_body.dig("errors", meal_type)
    end
  end

  test "reading more scheduled meals keeps query count bounded and preserves nested family data" do
    start_date = Date.new(2030, 1, 1)
    recipe = recipes(:scrambled_eggs_smith)
    6.times do |offset|
      day = @user.family.schedule_days.create!(date: start_date + offset)
      day.schedule_items.create!(kind: :recipe, meal_type: :breakfast, recipe: recipe)
    end
    first_day = @user.family.schedule_days.find_by!(date: start_date)
    first_day.schedule_items.create!(kind: :dining_out, meal_type: :lunch, dining_out_name: "Lunch out")
    other_day = families(:johnson_family).schedule_days.create!(date: start_date)
    other_day.schedule_items.create!(kind: :dining_out, meal_type: :dinner, dining_out_name: "Other family dinner")
    headers = auth_headers_for(@user)

    # Warm framework/schema caches before comparing the same HTTP interface.
    get "/v2/schedule", params: { start: start_date, end: start_date }, headers: headers
    one_day_queries = count_select_queries do
      get "/v2/schedule", params: { start: start_date, end: start_date }, headers: headers
    end
    week_queries = count_select_queries do
      get "/v2/schedule", params: { start: start_date, end: start_date + 6 }, headers: headers
    end

    assert_response :success
    assert_equal "success", response.parsed_body.fetch("status")
    days = response.parsed_body.fetch("data")
    assert_equal (start_date..start_date + 6).map(&:to_s), days.map { |day| day.fetch("date") }
    expected_recipe = RecipeSerializer.render(recipe).deep_stringify_keys.as_json
    assert_equal expected_recipe, days.first.dig("breakfast", "recipe")
    assert_equal "Lunch out", days.first.dig("lunch", "name")
    assert_nil days.first.fetch("dinner")
    assert_equal({ "date" => (start_date + 6).to_s, "breakfast" => nil, "lunch" => nil, "dinner" => nil }, days.last)
    assert_operator week_queries, :<=, one_day_queries,
      "expanding the Schedule should not add one query per day or meal (one day: #{one_day_queries}, week: #{week_queries})"
  end

  private

  def count_select_queries
    count = 0
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      # Include cache hits so repeated per-record loads cannot hide behind a warm query cache.
      count += 1 if payload[:name] != "SCHEMA" && payload[:sql].match?(/\ASELECT\b/i)
    end
    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
    end
    count
  end
end
