require "test_helper"

class V2ContractErrorsTest < ActionDispatch::IntegrationTest
  test "auth contracts report invalid email format" do
    post "/v2/login",
      params: {email: "not-an-email", password: "secret"},
      as: :json

    assert_contract_error(:unprocessable_entity, email: ["format invalid"])
  end

  test "invitation contracts report invalid email format" do
    user = users(:john_smith)

    post "/v2/invitations",
      params: {email: "not-an-email"},
      headers: auth_headers_for(user),
      as: :json

    assert_contract_error(:unprocessable_entity, email: ["format invalid"])
  end

  test "family preference contracts report invalid timezone" do
    user = users(:john_smith)

    patch "/v2/family/preferences",
      params: {timezone: "Moon/Base"},
      headers: auth_headers_for(user),
      as: :json

    assert_contract_error(:unprocessable_entity, timezone: ["is invalid"])
  end

  test "name collision contract requires q" do
    user = users(:john_smith)

    get "/v2/products/name_collision", headers: auth_headers_for(user)

    assert_contract_error(:unprocessable_entity, q: ["is missing"])
  end

  test "grocery preview contract requires date range aliases" do
    user = users(:john_smith)

    get "/v2/grocery_items/preview", headers: auth_headers_for(user)

    assert_contract_error(:unprocessable_entity, start: ["is required"], end: ["is required"])
  end

  test "grocery generate contract reports ISO date errors" do
    user = users(:john_smith)

    post "/v2/grocery_items/generate",
      params: {start_date: "nope", end_date: Date.current.iso8601},
      headers: auth_headers_for(user),
      as: :json

    assert_contract_error(:unprocessable_entity, start_date: ["must be ISO8601 date"])
  end

  test "grocery create contract enforces type-specific required fields" do
    user = users(:john_smith)

    post "/v2/grocery_items",
      params: {type: "custom", quantity: 1},
      headers: auth_headers_for(user),
      as: :json

    assert_contract_error(
      :unprocessable_entity,
      name: ["is required"],
      aisle: ["is required"],
      unit: ["is required"]
    )
  end

  test "schedule range contract requires start and end" do
    user = users(:john_smith)

    get "/v2/schedule", headers: auth_headers_for(user)

    assert_contract_error(:unprocessable_entity, start: ["is missing"], end: ["is missing"])
  end

  test "schedule write contract rejects empty updates" do
    user = users(:john_smith)

    put "/v2/schedule/#{Date.current.iso8601}",
      params: {},
      headers: auth_headers_for(user),
      as: :json

    assert_contract_error(:unprocessable_entity, base: ["must include at least one schedule field"])
  end

  test "consumption log contract reports ISO date errors" do
    user = users(:john_smith)

    post "/v2/consumption_logs",
      params: {recipe_id: recipes(:scrambled_eggs_smith).id, meal_type: "breakfast", schedule_date: "nope"},
      headers: auth_headers_for(user),
      as: :json

    assert_contract_error(:unprocessable_entity, schedule_date: ["must be ISO8601 date"])
  end

  private

  def assert_contract_error(status, expected_errors)
    assert_response status
    assert_equal "error", response.parsed_body["status"]

    expected_errors.each do |field, messages|
      assert_equal messages, response.parsed_body.dig("errors", field.to_s)
    end
  end
end
