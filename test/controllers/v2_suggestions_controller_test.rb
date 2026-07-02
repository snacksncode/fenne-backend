require "test_helper"

class V2SuggestionsControllerTest < ActionDispatch::IntegrationTest
  test "suppresses suggestions when family item with same normalized name exists" do
    user = users(:john_smith)
    Product.create!(family: user.family, name: "Sour Cream", aisle: :dairy_eggs, unit: :count)
    ProductSuggestion.create!(name: " sour cream ", aisle: :dairy_eggs)

    get "/v2/suggestions",
      params: {q: "sour", context: "recipe"},
      headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert_equal ["Sour Cream"], json.dig("data", "results").map { |item| item["name"] }
    assert_equal ["product"], json.dig("data", "results").map { |item| item["type"] }
    assert_not json.dig("data").key?("items")
    assert_not json.dig("data").key?("suggested")
  end

  test "shopping suggestions include kitchen basics" do
    user = users(:john_smith)
    Product.create!(family: user.family, name: "Salt", aisle: :spices_baking, unit: :count, is_kitchen_basic: true)

    get "/v2/suggestions",
      params: {q: "salt", context: "shopping"},
      headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert_equal ["Salt"], json.dig("data", "results").map { |item| item["name"] }
    assert_equal ["product"], json.dig("data", "results").map { |item| item["type"] }
  end

  test "pantry suggestions return existing products only" do
    user = users(:john_smith)
    Product.create!(family: user.family, name: "Coffee Beans", aisle: :pantry, unit: :count)
    ProductSuggestion.create!(name: "Coffee Filters", aisle: :pantry)

    get "/v2/suggestions",
      params: {q: "coffee", context: "pantry"},
      headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert_equal ["Coffee Beans"], json.dig("data", "results").map { |item| item["name"] }
    assert_equal ["product"], json.dig("data", "results").map { |item| item["type"] }
    assert_equal false, json.dig("data", "add_available")
  end

  test "suppresses duplicate suggestion even when family item is outside returned item limit" do
    user = users(:john_smith)
    11.times do |index|
      Product.create!(family: user.family, name: "Sour #{format("%02d", index)}", aisle: :dairy_eggs, unit: :count)
    end
    Product.create!(family: user.family, name: "Sour Zzz", aisle: :dairy_eggs, unit: :count)
    ProductSuggestion.create!(name: "Sour Zzz", aisle: :dairy_eggs)

    get "/v2/suggestions",
      params: {q: "sour", context: "recipe"},
      headers: auth_headers_for(user)

    assert_response :success
    assert_not_includes response.parsed_body.dig("data", "results").map { |item| item["name"] }, "Sour Zzz"
  end

  test "ranks prefix and shorter matches ahead of contains matches" do
    user = users(:john_smith)
    ProductSuggestion.create!(name: "Acorn Squash", aisle: :produce)
    ProductSuggestion.create!(name: "Caramel Corn", aisle: :snacks)
    ProductSuggestion.create!(name: "Coriander", aisle: :spices_baking)
    ProductSuggestion.create!(name: "Corn", aisle: :produce)
    ProductSuggestion.create!(name: "Corn Chips", aisle: :snacks)

    get "/v2/suggestions",
      params: {q: "cor", context: "shopping"},
      headers: auth_headers_for(user)

    assert_response :success
    result_names = response.parsed_body.dig("data", "results").map { |item| item["name"] }
    assert_equal "Corn", result_names.first
    assert_not_includes result_names, "Acorn Squash"
    assert_operator result_names.index("Corn Chips"), :<, result_names.index("Caramel Corn")
  end
end
