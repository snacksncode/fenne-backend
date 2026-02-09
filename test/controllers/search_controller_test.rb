require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  # GET /search
  test "index returns matching food items" do
    user = users(:john_smith)

    # Create some test food items
    FoodItem.create!(name: "Tomato", aisle: :produce, family_id: nil)
    FoodItem.create!(name: "Tomato Sauce", aisle: :condiments_sauces, family_id: nil)
    FoodItem.create!(name: "Cherry Tomatoes", aisle: :produce, family_id: nil)

    get "/search", params: {q: "tomato"}, headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert json.is_a?(Array)
    assert json.length > 0
    json.each do |item|
      assert_includes item["name"].downcase, "tomato"
    end
  end

  test "index returns global and family-specific items" do
    user = users(:john_smith)

    FoodItem.create!(name: "Global Apple", aisle: :produce, family_id: nil)
    FoodItem.create!(name: "Family Apple Pie", aisle: :bakery, family_id: user.family_id)
    FoodItem.create!(name: "Other Apple Juice", aisle: :beverages, family_id: families(:johnson_family).id)

    get "/search", params: {q: "apple"}, headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    names = json.map { |item| item["name"] }

    assert_includes names, "Global Apple"
    assert_includes names, "Family Apple Pie"
    assert_not_includes names, "Other Apple Juice"
  end

  test "index limits results to 10 items" do
    user = users(:john_smith)

    # Create 15 items
    15.times do |i|
      FoodItem.create!(name: "Test Item #{i}", aisle: :produce, family_id: nil)
    end

    get "/search", params: {q: "test"}, headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert json.length <= 10
  end

  test "index returns error for missing query" do
    user = users(:john_smith)

    get "/search", headers: auth_headers_for(user)

    assert_response :bad_request
    json = response.parsed_body
    assert_includes json["error"], "Missing query string"
  end

  test "index returns error for blank query" do
    user = users(:john_smith)

    get "/search", params: {q: ""}, headers: auth_headers_for(user)

    assert_response :bad_request
  end

  test "index requires authentication" do
    get "/search", params: {q: "test"}

    assert_response :unauthorized
  end

  test "index is case insensitive" do
    user = users(:john_smith)

    FoodItem.create!(name: "Banana", aisle: :produce, family_id: nil)

    get "/search", params: {q: "BANANA"}, headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert json.length > 0
  end

  # DELETE /search/:id
  test "destroy deletes family-specific food item" do
    user = users(:john_smith)
    food_item = FoodItem.create!(name: "Custom Item", aisle: :produce, family_id: user.family_id)

    assert_difference("FoodItem.count", -1) do
      delete "/search/#{food_item.id}", headers: auth_headers_for(user)
    end

    assert_response :success
    assert_not FoodItem.exists?(food_item.id)
  end

  test "destroy returns error for global food item" do
    user = users(:john_smith)
    global_item = FoodItem.create!(name: "Global Item", aisle: :produce, family_id: nil)

    delete "/search/#{global_item.id}", headers: auth_headers_for(user)

    assert_response :bad_request
    assert FoodItem.exists?(global_item.id)
  end

  test "destroy returns error for other family's food item" do
    user = users(:john_smith)
    other_family_item = FoodItem.create!(name: "Other Item", aisle: :produce, family_id: families(:johnson_family).id)

    delete "/search/#{other_family_item.id}", headers: auth_headers_for(user)

    assert_response :bad_request
    assert FoodItem.exists?(other_family_item.id)
  end

  test "destroy requires authentication" do
    food_item = FoodItem.create!(name: "Test", aisle: :produce, family_id: families(:smith_family).id)

    delete "/search/#{food_item.id}"

    assert_response :unauthorized
  end
end
