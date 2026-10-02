require "test_helper"

class V2RecipesControllerTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  test "recipe save can create product drafts atomically" do
    user = users(:john_smith)

    assert_difference([ "Recipe.count", "Product.count", "Ingredient.count" ], 1) do
      post "/v2/recipes",
        params: {
          name: "Rice Bowl",
          meal_types: [ "dinner" ],
          time_in_minutes: 20,
          ingredients: [
            {
              quantity: 150,
              unit: "g",
              product: { name: "Rice", aisle: "pantry", unit: "g" }
            }
          ]
        },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :created
    json = response.parsed_body
    assert_equal "success", json["status"]
    assert_equal "Rice", json.dig("data", "ingredients", 0, "product", "name")
  end

  test "recipe save ignores existing product fields beyond id" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Rice", aisle: :pantry, unit: :g)

    post "/v2/recipes",
      params: {
        name: "Rice Bowl",
        meal_types: [ "dinner" ],
        time_in_minutes: 20,
        ingredients: [
          {
            quantity: 150,
            unit: "g",
            product: { id: product.id, name: "Better Rice" }
          }
        ]
      },
      headers: auth_headers_for(user),
      as: :json

    assert_response :created
    assert_equal "Rice", product.reload.name
    assert_equal product.id.to_s, response.parsed_body.dig("data", "ingredients", 0, "product", "id")
  end

  test "recipe save ignores submitted conversions for existing products" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Butter", aisle: :dairy_eggs, unit: :g)

    post "/v2/recipes",
      params: {
        name: "Toast",
        meal_types: [ "breakfast" ],
        time_in_minutes: 5,
        ingredients: [
          {
            quantity: 1,
            unit: "tbsp",
            product: { id: product.id, conversions: { tbsp: 14 } }
          }
        ]
      },
      headers: auth_headers_for(user),
      as: :json

    assert_response :unprocessable_entity
    assert_equal [
      {
        "ingredient_index" => 0,
        "product_id" => product.id.to_s,
        "product_name" => "Butter",
        "ingredient_unit" => "tbsp",
        "product_unit" => "g"
      }
    ], response.parsed_body.dig("errors", "missing_conversions")
    assert_equal({}, product.reload.conversions)
  end

  test "recipe save reports every missing conversion with ingredient context and rolls back" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Conversion Butter", aisle: :dairy_eggs, unit: :g)

    assert_no_difference([ "Recipe.count", "Product.count", "Ingredient.count" ]) do
      post "/v2/recipes",
        params: {
          name: "Conversion Test Recipe",
          meal_types: [ "breakfast" ],
          time_in_minutes: 5,
          ingredients: [
            {
              quantity: 1,
              unit: "tbsp",
              product: { id: product.id }
            },
            {
              quantity: 1,
              unit: "cup",
              product: { name: "Conversion Flour", aisle: "spices_baking", unit: "g" }
            }
          ]
        },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :unprocessable_entity
    assert_equal [
      {
        "ingredient_index" => 0,
        "product_id" => product.id.to_s,
        "product_name" => "Conversion Butter",
        "ingredient_unit" => "tbsp",
        "product_unit" => "g"
      },
      {
        "ingredient_index" => 1,
        "product_id" => nil,
        "product_name" => "Conversion Flour",
        "ingredient_unit" => "cup",
        "product_unit" => "g"
      }
    ], response.parsed_body.dig("errors", "missing_conversions")
  end

  test "recipe ingredient can override and clear product display name" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Eggs", aisle: :dairy_eggs, unit: :count)

    post "/v2/recipes",
      params: {
        name: "Custard",
        meal_types: [ "breakfast" ],
        time_in_minutes: 15,
        ingredients: [
          {
            name_override: "Yolk",
            quantity: 2,
            unit: "count",
            product: { id: product.id }
          }
        ]
      },
      headers: auth_headers_for(user),
      as: :json

    assert_response :created
    recipe_id = response.parsed_body.dig("data", "id")
    assert_equal "Yolk", response.parsed_body.dig("data", "ingredients", 0, "name")
    assert_equal "Yolk", response.parsed_body.dig("data", "ingredients", 0, "name_override")

    patch "/v2/recipes/#{recipe_id}",
      params: {
        ingredients: [
          {
            name_override: nil,
            quantity: 2,
            unit: "count",
            product: { id: product.id }
          }
        ]
      },
      headers: auth_headers_for(user),
      as: :json

    assert_response :success
    assert_equal "Eggs", response.parsed_body.dig("data", "ingredients", 0, "name")
    assert_nil response.parsed_body.dig("data", "ingredients", 0, "name_override")
  end

  test "recipe patch can update scalar fields without resending ingredients" do
    user = users(:john_smith)
    recipe = recipes(:scrambled_eggs_smith)
    original_ingredient_ids = recipe.ingredients.pluck(:id).sort

    patch "/v2/recipes/#{recipe.id}",
      params: { notes: "Add chives at the end" },
      headers: auth_headers_for(user),
      as: :json

    assert_response :success
    assert_equal "Add chives at the end", recipe.reload.notes
    assert_equal original_ingredient_ids, recipe.ingredients.pluck(:id).sort
  end

  test "recipe edits broadcast one representative per scheduled week nearest today first" do
    user = users(:john_smith)
    recipe = recipes(:scrambled_eggs_smith)
    stream = "family_invalidation_stream_#{user.family_id}"
    [ Date.new(2030, 1, 3), Date.new(2030, 1, 1), Date.new(2030, 1, 9) ].each do |date|
      day = user.family.schedule_days.create!(date: date)
      day.schedule_items.create!(kind: :recipe, meal_type: :breakfast, recipe: recipe)
    end
    other_family = families(:johnson_family)
    other_day = other_family.schedule_days.create!(date: Date.new(2030, 1, 20))
    other_day.schedule_items.create!(kind: :recipe, meal_type: :dinner, recipe: recipes(:grilled_salmon_johnson))
    user.session_tokens.update_all(expires_at: Time.zone.local(2031, 1, 1))

    travel_to Time.zone.local(2030, 1, 10, 12) do
      assert_no_broadcasts("family_invalidation_stream_#{other_family.id}") do
        messages = capture_broadcasts(stream) do
          patch "/v2/recipes/#{recipe.id}", params: { notes: "Updated notes" }, headers: auth_headers_for(user), as: :json
        end
        assert_response :success
        assert_equal [
          { "resource" => "recipes", "data" => nil },
          { "resource" => "schedules", "data" => { "dates" => [ "2030-01-09", "2030-01-03" ] } }
        ], messages
      end
    end
  end

  test "deleting a scheduled recipe broadcasts the full schedule fallback after removing its meals" do
    user = users(:john_smith)
    recipe = recipes(:scrambled_eggs_smith)
    day = user.family.schedule_days.create!(date: Date.new(2030, 1, 1))
    day.schedule_items.create!(kind: :recipe, meal_type: :breakfast, recipe: recipe)

    messages = capture_broadcasts("family_invalidation_stream_#{user.family_id}") do
      delete "/v2/recipes/#{recipe.id}", headers: auth_headers_for(user), as: :json
    end

    assert_response :success
    assert_empty day.schedule_items.reload
    assert_equal [
      { "resource" => "recipes", "data" => nil },
      { "resource" => "schedules", "data" => nil }
    ], messages
  end

  test "invalid recipe edits do not broadcast changes" do
    user = users(:john_smith)
    assert_no_broadcasts("family_invalidation_stream_#{user.family_id}") do
      patch "/v2/recipes/#{recipes(:scrambled_eggs_smith).id}", params: { name: "" }, headers: auth_headers_for(user), as: :json
    end
    assert_response :unprocessable_entity
  end

  test "recipe creation treats repeated meal types as one selection" do
    user = users(:john_smith)
    ingredient = recipes(:scrambled_eggs_smith).ingredients.first

    post "/v2/recipes", params: {
      name: "Breakfast twice",
      meal_types: [ "breakfast", "breakfast" ],
      time_in_minutes: 10,
      ingredients: [ { quantity: 1, unit: ingredient.unit, product: { id: ingredient.product_id } } ]
    }, headers: auth_headers_for(user), as: :json

    assert_response :created
    assert_equal "success", response.parsed_body.fetch("status")
    assert_equal [ "breakfast" ], response.parsed_body.dig("data", "meal_types")
    saved = user.family.recipes.find(response.parsed_body.dig("data", "id"))
    assert_equal [ :breakfast ], saved.meal_types
  end

  test "recipe edits preserve selected meal types when a selection is repeated" do
    user = users(:john_smith)
    recipe = recipes(:scrambled_eggs_smith)

    patch "/v2/recipes/#{recipe.id}", params: {
      meal_types: [ "lunch", "lunch" ]
    }, headers: auth_headers_for(user), as: :json

    assert_response :success
    assert_equal [ "lunch" ], response.parsed_body.dig("data", "meal_types")
    assert_equal [ :lunch ], recipe.reload.meal_types
  end

  test "empty or unknown meal types remain invalid for recipe creation and edits" do
    user = users(:john_smith)
    recipe = recipes(:scrambled_eggs_smith)
    ingredient = recipe.ingredients.first
    original_types = recipe.meal_types

    [ [], [ "snack" ], [ "breakfast", "snack" ] ].each do |meal_types|
      assert_no_difference "Recipe.count" do
        post "/v2/recipes", params: {
          name: "Invalid meal types",
          meal_types: meal_types,
          time_in_minutes: 10,
          ingredients: [ { quantity: 1, unit: ingredient.unit, product: { id: ingredient.product_id } } ]
        }, headers: auth_headers_for(user), as: :json
      end
      assert_response :unprocessable_entity
      assert_equal "error", response.parsed_body.fetch("status")
      assert response.parsed_body.fetch("errors").key?("meal_types")

      patch "/v2/recipes/#{recipe.id}", params: { meal_types: meal_types }, headers: auth_headers_for(user), as: :json
      assert_response :unprocessable_entity
      assert_equal "error", response.parsed_body.fetch("status")
      assert response.parsed_body.fetch("errors").key?("meal_types")
      assert_equal original_types, recipe.reload.meal_types
    end
  end
end
