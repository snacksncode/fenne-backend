require "test_helper"

class V2RecipesControllerTest < ActionDispatch::IntegrationTest
  test "recipe save can create product drafts atomically" do
    user = users(:john_smith)

    assert_difference(["Recipe.count", "Product.count", "Ingredient.count"], 1) do
      post "/v2/recipes",
        params: {
          name: "Rice Bowl",
          meal_types: ["dinner"],
          time_in_minutes: 20,
          ingredients: [
            {
              quantity: 150,
              unit: "g",
              product: {name: "Rice", aisle: "pantry", quantity: 500, unit: "g"}
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
    product = Product.create!(family: user.family, name: "Rice", aisle: :pantry, quantity: 500, unit: :g)

    post "/v2/recipes",
      params: {
        name: "Rice Bowl",
        meal_types: ["dinner"],
        time_in_minutes: 20,
        ingredients: [
          {
            quantity: 150,
            unit: "g",
            product: {id: product.id, name: "Better Rice"}
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
    product = Product.create!(family: user.family, name: "Butter", aisle: :dairy_eggs, quantity: 200, unit: :g)

    post "/v2/recipes",
      params: {
        name: "Toast",
        meal_types: ["breakfast"],
        time_in_minutes: 5,
        ingredients: [
          {
            quantity: 1,
            unit: "tbsp",
            product: {id: product.id, conversions: {tbsp: 14}}
          }
        ]
      },
      headers: auth_headers_for(user),
      as: :json

    assert_response :unprocessable_entity
    assert_equal ["tbsp"], response.parsed_body.dig("errors", "missing_conversions")
    assert_equal({}, product.reload.conversions)
  end

  test "recipe ingredient can override and clear product display name" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Eggs", aisle: :dairy_eggs, unit: :count)

    post "/v2/recipes",
      params: {
        name: "Custard",
        meal_types: ["breakfast"],
        time_in_minutes: 15,
        ingredients: [
          {
            name_override: "Yolk",
            quantity: 2,
            unit: "count",
            product: {id: product.id}
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
            product: {id: product.id}
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
      params: {notes: "Add chives at the end"},
      headers: auth_headers_for(user),
      as: :json

    assert_response :success
    assert_equal "Add chives at the end", recipe.reload.notes
    assert_equal original_ingredient_ids, recipe.ingredients.pluck(:id).sort
  end
end
