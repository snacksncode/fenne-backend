require "test_helper"

class V2ConsumptionLogsControllerTest < ActionDispatch::IntegrationTest
  test "undo restores pantry from snapshot after recipe is deleted" do
    user = users(:john_smith)
    recipe = recipes(:scrambled_eggs_smith)
    product = Product.create!(family: user.family, name: "Eggs", aisle: :dairy_eggs, unit: :count)
    ingredients(:scrambled_eggs_eggs).update!(product: product)
    PantryEntry.create!(family: user.family, product: product, quantity_remaining: 3, last_acquired: Time.current)

    post "/v2/consumption_logs",
      params: { recipe_id: recipe.id, meal_type: "breakfast", schedule_date: Date.current.iso8601 },
      headers: auth_headers_for(user),
      as: :json

    assert_response :created
    log_id = response.parsed_body.dig("data", "id")
    assert_equal recipe.name, response.parsed_body.dig("data", "recipe_name")
    assert_equal 1.0, PantryEntry.find_by(product: product).quantity_remaining.to_f

    recipe.destroy!

    delete "/v2/consumption_logs/#{log_id}", headers: auth_headers_for(user)

    assert_response :success
    assert_equal 3.0, PantryEntry.find_by(product: product).quantity_remaining.to_f
  end

  test "undo converts snapshot when measured product unit changed compatibly" do
    user = users(:john_smith)
    recipe = recipes(:scrambled_eggs_smith)
    product = Product.create!(family: user.family, name: "Butter", aisle: :dairy_eggs, unit: :g)
    ingredients(:scrambled_eggs_butter).update!(product: product, quantity: 100, unit: :g)
    PantryEntry.create!(family: user.family, product: product, quantity_remaining: 500, last_acquired: Time.current)

    post "/v2/consumption_logs",
      params: { recipe_id: recipe.id, meal_type: "breakfast", schedule_date: Date.current.iso8601 },
      headers: auth_headers_for(user),
      as: :json

    assert_response :created
    log_id = response.parsed_body.dig("data", "id")
    assert_equal 400.0, PantryEntry.find_by!(product: product).quantity_remaining.to_f

    patch "/v2/products/#{product.id}",
      params: { unit: "kg" },
      headers: auth_headers_for(user),
      as: :json

    assert_response :success
    assert_equal 0.4, PantryEntry.find_by!(product: product).quantity_remaining.to_f

    delete "/v2/consumption_logs/#{log_id}", headers: auth_headers_for(user)

    assert_response :success
    assert_equal 0.5, PantryEntry.find_by!(product: product).quantity_remaining.to_f
  end

  test "undo skips snapshot when product tracking shape changed incompatibly" do
    user = users(:john_smith)
    recipe = recipes(:scrambled_eggs_smith)
    product = Product.create!(family: user.family, name: "Eggs", aisle: :dairy_eggs, unit: :count)
    ingredients(:scrambled_eggs_eggs).update!(product: product)
    PantryEntry.create!(family: user.family, product: product, quantity_remaining: 3, last_acquired: Time.current)

    post "/v2/consumption_logs",
      params: { recipe_id: recipe.id, meal_type: "breakfast", schedule_date: Date.current.iso8601 },
      headers: auth_headers_for(user),
      as: :json

    assert_response :created
    log_id = response.parsed_body.dig("data", "id")
    product.update_columns(unit: Product.units[:g])

    delete "/v2/consumption_logs/#{log_id}", headers: auth_headers_for(user)

    assert_response :success
    assert_equal "Some pantry quantities could not be restored", response.parsed_body.dig("meta", "warning")
    assert_equal 1.0, PantryEntry.find_by!(product: product).quantity_remaining.to_f
  end
end
