require "test_helper"

class RecipesControllerTest < ActionDispatch::IntegrationTest
  # GET /recipes
  test "index returns family recipes only" do
    user = users(:john_smith)

    get "/recipes", headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert json.is_a?(Array)
    assert json.length > 0
    json.each do |recipe|
      assert_equal user.family_id, Recipe.find(recipe["id"]).family_id
    end
  end

  test "index requires authentication" do
    get "/recipes"

    assert_response :unauthorized
  end

  # GET /recipes/:id
  test "show returns recipe with ingredients" do
    user = users(:john_smith)
    recipe = recipes(:pasta_carbonara_smith)

    get "/recipes/#{recipe.id}", headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert_equal recipe.id.to_s, json["id"]
    assert_equal recipe.name, json["name"]
    assert json["ingredients"].is_a?(Array)
  end

  test "show returns 404 for other family's recipe" do
    user = users(:john_smith)
    other_recipe = recipes(:grilled_salmon_johnson)

    get "/recipes/#{other_recipe.id}", headers: auth_headers_for(user)

    assert_response :not_found
  end

  test "show requires authentication" do
    recipe = recipes(:pasta_carbonara_smith)

    get "/recipes/#{recipe.id}"

    assert_response :unauthorized
  end

  # POST /recipes
  test "create creates recipe with ingredients" do
    user = users(:john_smith)

    assert_difference("Recipe.count", 1) do
      assert_difference("Ingredient.count", 2) do
        post "/recipes",
          params: {
            data: {
              name: "New Recipe",
              meal_types: ["breakfast", "lunch"],
              time_in_minutes: 30,
              liked: false,
              ingredients: [
                {name: "Flour", quantity: 2.0, unit: "cup", aisle: "spices_baking"},
                {name: "Milk", quantity: 1.0, unit: "cup", aisle: "dairy_eggs"}
              ]
            }
          },
          headers: auth_headers_for(user),
          as: :json
      end
    end

    assert_response :success
    json = response.parsed_body
    assert_equal "New Recipe", json["name"]
    assert_equal 2, json["ingredients"].length
  end

  test "create validates required fields" do
    user = users(:john_smith)

    assert_no_difference("Recipe.count") do
      post "/recipes",
        params: {data: {name: ""}},
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :unprocessable_entity
  end

  test "create validates meal_types" do
    user = users(:john_smith)

    assert_no_difference("Recipe.count") do
      post "/recipes",
        params: {
          data: {
            name: "Test",
            meal_types: [],
            time_in_minutes: 30,
            ingredients: [{name: "Test", quantity: 1.0, unit: "cup", aisle: "produce"}]
          }
        },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :unprocessable_entity
  end

  test "create validates ingredients" do
    user = users(:john_smith)

    assert_no_difference("Recipe.count") do
      post "/recipes",
        params: {
          data: {
            name: "Test",
            meal_types: ["breakfast"],
            time_in_minutes: 30,
            ingredients: []
          }
        },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :unprocessable_entity
  end

  test "create requires authentication" do
    post "/recipes",
      params: {data: {name: "Test"}},
      as: :json

    assert_response :unauthorized
  end

  # PUT /recipes/:id
  test "update updates recipe and ingredients" do
    user = users(:john_smith)
    recipe = recipes(:pasta_carbonara_smith)

    put "/recipes/#{recipe.id}",
      params: {
        data: {
          name: "Updated Recipe",
          meal_types: ["dinner"],
          time_in_minutes: 45,
          liked: true,
          ingredients: [
            {name: "New Ingredient", quantity: 3.0, unit: "tbsp", aisle: "condiments_sauces"}
          ]
        }
      },
      headers: auth_headers_for(user),
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal "Updated Recipe", json["name"]
    assert_equal 1, json["ingredients"].length
    assert_equal "New Ingredient", json["ingredients"][0]["name"]
  end

  test "update returns 404 for other family's recipe" do
    user = users(:john_smith)
    other_recipe = recipes(:grilled_salmon_johnson)

    put "/recipes/#{other_recipe.id}",
      params: {data: {name: "Hacked"}},
      headers: auth_headers_for(user),
      as: :json

    assert_response :not_found
    other_recipe.reload
    assert_not_equal "Hacked", other_recipe.name
  end

  test "update requires authentication" do
    recipe = recipes(:pasta_carbonara_smith)

    put "/recipes/#{recipe.id}",
      params: {data: {name: "Updated"}},
      as: :json

    assert_response :unauthorized
  end

  # DELETE /recipes/:id
  test "destroy deletes recipe and ingredients" do
    user = users(:john_smith)
    recipe = recipes(:pasta_carbonara_smith)
    ingredient_ids = recipe.ingredients.pluck(:id)

    assert_difference("Recipe.count", -1) do
      delete "/recipes/#{recipe.id}", headers: auth_headers_for(user)
    end

    assert_response :success
    ingredient_ids.each do |id|
      assert_not Ingredient.exists?(id)
    end
  end

  test "destroy returns 404 for other family's recipe" do
    user = users(:john_smith)
    other_recipe = recipes(:grilled_salmon_johnson)

    assert_no_difference("Recipe.count") do
      delete "/recipes/#{other_recipe.id}", headers: auth_headers_for(user)
    end

    assert_response :not_found
  end

  test "destroy requires authentication" do
    recipe = recipes(:pasta_carbonara_smith)

    delete "/recipes/#{recipe.id}"

    assert_response :unauthorized
  end
end
