require "test_helper"

class V2ProductsControllerTest < ActionDispatch::IntegrationTest
  test "creates product and returns v2 envelope" do
    user = users(:john_smith)

    assert_difference("Product.count", 1) do
      post "/v2/products",
        params: { name: "Sour Cream", aisle: "dairy_eggs", quantity: 200, unit: "g" },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :created
    json = response.parsed_body
    assert_equal "success", json["status"]
    assert_equal "Sour Cream", json.dig("data", "name")
    assert_equal "measured", json.dig("data", "shape")
  end

  test "name collision endpoint uses normalized family product names" do
    user = users(:john_smith)
    Product.create!(family: user.family, name: " Sour Cream ", aisle: :dairy_eggs, unit: :count)

    get "/v2/products/name_collision",
      params: { q: "sour cream" },
      headers: auth_headers_for(user)

    assert_response :success
    assert_equal true, response.parsed_body.dig("data", "exists")
  end

  test "create rejects quantity with count unit" do
    user = users(:john_smith)

    assert_no_difference("Product.count") do
      post "/v2/products",
        params: { name: "Eggs", aisle: "dairy_eggs", quantity: 12, unit: "count" },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :unprocessable_entity
    assert_equal [ "Quantity cannot be used with count unit" ], response.parsed_body.dig("errors", "quantity")
  end

  test "destructive product edit returns impact and acknowledged retry clears impacted rows" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Olive Oil", aisle: :pantry, unit: :count)
    PantryEntry.create!(family: user.family, product: product, quantity_remaining: 1, last_acquired: Time.current)
    GroceryItem.create!(
      family: user.family,
      product: product,
      name: product.name,
      aisle: product.aisle,
      unit: product.unit,
      quantity: 1,
      status: :pending
    )

    patch "/v2/products/#{product.id}",
      params: { reminder_frequency_value: 2, reminder_frequency_unit: "months" },
      headers: auth_headers_for(user),
      as: :json

    assert_response :precondition_required
    assert_equal [ "pantry", "shopping_list" ], response.parsed_body.dig("errors", "impact").sort
    assert PantryEntry.exists?(product: product)
    assert GroceryItem.exists?(product: product)

    patch "/v2/products/#{product.id}",
      params: { reminder_frequency_value: 2, reminder_frequency_unit: "months", impact_acknowledged: true },
      headers: auth_headers_for(user),
      as: :json

    assert_response :success
    assert_not PantryEntry.exists?(product: product)
    assert_not GroceryItem.exists?(product: product)
  end

  test "measured product edit reports missing recipe conversions" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Butter", aisle: :dairy_eggs, unit: :count)
    ingredient = ingredients(:scrambled_eggs_butter)
    ingredient.update!(product: product)

    patch "/v2/products/#{product.id}",
      params: { quantity: 200, unit: "g" },
      headers: auth_headers_for(user),
      as: :json

    assert_response :unprocessable_entity
    assert_equal [ "tbsp" ], response.parsed_body.dig("errors", "missing_conversions")
  end

  test "same dimension measured unit change converts pantry and shopping quantities" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Flour", aisle: :spices_baking, quantity: 1, unit: :kg)
    pantry = PantryEntry.create!(family: user.family, product: product, quantity_remaining: 0.5, last_acquired: Time.current)
    grocery = GroceryItem.create!(
      family: user.family,
      product: product,
      name: product.name,
      aisle: product.aisle,
      unit: product.unit,
      quantity: 1,
      status: :pending
    )

    patch "/v2/products/#{product.id}",
      params: { quantity: 1000, unit: "g" },
      headers: auth_headers_for(user),
      as: :json

    assert_response :success
    assert_equal 500.0, pantry.reload.quantity_remaining.to_f
    assert_equal 1000.0, grocery.reload.quantity.to_f
    assert_equal "g", grocery.unit
  end

  test "same dimension measured unit change converts stored product conversions" do
    user = users(:john_smith)
    product = Product.create!(
      family: user.family,
      name: "Conversion Yogurt",
      aisle: :dairy_eggs,
      quantity: 500,
      unit: :g,
      conversions: {"tbsp" => 15}
    )

    patch "/v2/products/#{product.id}",
      params: {quantity: 0.5, unit: "kg"},
      headers: auth_headers_for(user),
      as: :json

    assert_response :success
    assert_in_delta 0.015, product.reload.conversions.fetch("tbsp").to_f
  end

  test "cross dimension measured unit change rejects stale product conversions" do
    user = users(:john_smith)
    product = Product.create!(
      family: user.family,
      name: "Conversion Sauce",
      aisle: :condiments_sauces,
      quantity: 500,
      unit: :g,
      conversions: {"tbsp" => 15}
    )
    recipe = Recipe.create!(family: user.family, name: "Conversion Dip", meal_types: [:lunch], time_in_minutes: 5)
    recipe.ingredients.create!(product: product, quantity: 1, unit: :tbsp)

    patch "/v2/products/#{product.id}",
      params: {quantity: 500, unit: "ml"},
      headers: auth_headers_for(user),
      as: :json

    assert_response :unprocessable_entity
    assert_equal ["tbsp"], response.parsed_body.dig("errors", "missing_conversions")
    assert_equal "g", product.reload.unit
    assert_equal 15, product.conversions.fetch("tbsp")
  end

  test "equivalent measured unit change still reports shopping impact when pack count changes" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Flour", aisle: :spices_baking, quantity: 1, unit: :kg)
    GroceryItem.create!(
      family: user.family,
      product: product,
      name: product.name,
      aisle: product.aisle,
      unit: product.unit,
      quantity: 1,
      status: :pending
    )

    patch "/v2/products/#{product.id}",
      params: { quantity: 1000, unit: "g", pack_count: 2 },
      headers: auth_headers_for(user),
      as: :json

    assert_response :precondition_required
    assert_equal [ "shopping_list" ], response.parsed_body.dig("errors", "impact")
  end

  test "destroy rejects product with pantry stock" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Rice", aisle: :pantry, unit: :count)
    entry = PantryEntry.create!(family: user.family, product: product, quantity_remaining: 2, last_acquired: Time.current)

    assert_no_difference("Product.count") do
      delete "/v2/products/#{product.id}",
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :conflict
    assert_equal entry.id.to_s, response.parsed_body.dig("errors", "pantry_entries", 0, "id")
  end
end
