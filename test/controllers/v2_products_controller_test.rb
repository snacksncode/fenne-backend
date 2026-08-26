require "test_helper"

class V2ProductsControllerTest < ActionDispatch::IntegrationTest
  test "creates product and returns v2 envelope" do
    user = users(:john_smith)

    assert_difference("Product.count", 1) do
      post "/v2/products",
        params: { name: "Sour Cream", aisle: "dairy_eggs", unit: "g" },
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

  test "create defaults to counted tracking when unit is count" do
    user = users(:john_smith)

    assert_difference("Product.count", 1) do
      post "/v2/products",
        params: { name: "Eggs", aisle: "dairy_eggs", unit: "count" },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :created
    assert_equal "counted", response.parsed_body.dig("data", "shape")
  end

  test "create preserves a measured unit for reminder mode" do
    user = users(:john_smith)

    assert_difference("Product.count", 1) do
      post "/v2/products",
        params: {
          name: "Coffee",
          aisle: "pantry",
          unit: "g",
          reminder_frequency_value: 2,
          reminder_frequency_unit: "weeks"
        },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :created
    assert_equal "timed", response.parsed_body.dig("data", "shape")
    assert_equal "g", response.parsed_body.dig("data", "unit")
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
      params: { unit: "g" },
      headers: auth_headers_for(user),
      as: :json

    assert_response :unprocessable_entity
    assert_equal [ "tbsp" ], response.parsed_body.dig("errors", "missing_conversions")
  end

  test "same dimension measured unit change converts pantry and shopping quantities" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Flour", aisle: :spices_baking, unit: :kg)
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
      params: { unit: "g" },
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
      unit: :g,
      conversions: {"tbsp" => 15}
    )

    patch "/v2/products/#{product.id}",
      params: {unit: "kg"},
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
      unit: :g,
      conversions: {"tbsp" => 15}
    )
    recipe = Recipe.create!(family: user.family, name: "Conversion Dip", meal_types: [:lunch], time_in_minutes: 5)
    recipe.ingredients.create!(product: product, quantity: 1, unit: :tbsp)

    patch "/v2/products/#{product.id}",
      params: {unit: "ml"},
      headers: auth_headers_for(user),
      as: :json

    assert_response :unprocessable_entity
    assert_equal ["tbsp"], response.parsed_body.dig("errors", "missing_conversions")
    assert_equal "g", product.reload.unit
    assert_equal 15, product.conversions.fetch("tbsp")
  end

  test "destroy removes associated pantry and grocery items" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Rice", aisle: :pantry, unit: :count)
    PantryEntry.create!(family: user.family, product: product, quantity_remaining: 2, last_acquired: Time.current)
    GroceryItem.create!(
      family: user.family,
      product: product,
      name: product.name,
      aisle: product.aisle,
      unit: product.unit,
      quantity: 1,
      status: :pending
    )

    assert_difference([ "Product.count", "PantryEntry.count", "GroceryItem.count" ], -1) do
      assert_broadcasts("family_invalidation_stream_#{user.family.id}", 3) do
        delete "/v2/products/#{product.id}",
          headers: auth_headers_for(user),
          as: :json
      end
    end

    assert_response :success
  end

  test "destroy removes an unreferenced product" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Unused Item", aisle: :other, unit: :count)

    assert_difference("Product.count", -1) do
      delete "/v2/products/#{product.id}",
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :success
    assert_equal "success", response.parsed_body.fetch("status")
  end

  test "usages returns family recipes that reference the product" do
    user = users(:john_smith)
    ingredient = ingredients(:scrambled_eggs_butter)

    get "/v2/products/#{ingredient.product_id}/usages",
      headers: auth_headers_for(user)

    assert_response :success
    recipes = response.parsed_body.dig("data", "recipes")
    assert_equal [ ingredient.recipe_id.to_s ], recipes.map { |recipe| recipe.fetch("id") }
    assert_equal ingredient.recipe.name, recipes.first.fetch("name")
  end

  test "usages does not expose another family's product" do
    user = users(:john_smith)
    other_product = products(:johnson_fixture_salmon)

    get "/v2/products/#{other_product.id}/usages",
      headers: auth_headers_for(user)

    assert_response :not_found
    assert_equal "error", response.parsed_body.fetch("status")
  end

  test "destroy returns blocking recipes when product is used by a recipe" do
    user = users(:john_smith)
    ingredient = ingredients(:scrambled_eggs_butter)
    product = ingredient.product
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

    assert_no_difference([ "Product.count", "PantryEntry.count", "GroceryItem.count" ]) do
      delete "/v2/products/#{product.id}",
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :conflict
    blocking_recipe = response.parsed_body.dig("errors", "recipes", 0)
    assert_equal ingredient.recipe_id.to_s, blocking_recipe.fetch("id")
    assert_equal ingredient.recipe.name, blocking_recipe.fetch("name")
    assert blocking_recipe.fetch("ingredients").any?
    assert_not response.parsed_body.fetch("errors").key?("pantry_entries")
    assert_not response.parsed_body.fetch("errors").key?("grocery_items")
  end
end
