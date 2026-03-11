require "test_helper"

class GroceryItemsControllerTest < ActionDispatch::IntegrationTest
  # GET /grocery_items
  test "index returns family grocery items" do
    user = users(:john_smith)

    get "/grocery_items", headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert json.is_a?(Array)
    assert json.length > 0
  end

  test "index requires authentication" do
    get "/grocery_items"

    assert_response :unauthorized
  end

  # GET /grocery_items/:id
  test "show returns grocery item" do
    user = users(:john_smith)
    item = grocery_items(:smith_milk)

    get "/grocery_items/#{item.id}", headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert_equal item.id.to_s, json["id"]
    assert_equal item.name, json["name"]
  end

  test "show returns 404 for other family's item" do
    user = users(:john_smith)
    other_item = GroceryItem.create!(
      family: families(:johnson_family),
      name: "Other Item",
      quantity: 1,
      aisle: :produce,
      unit: :count
    )

    get "/grocery_items/#{other_item.id}", headers: auth_headers_for(user)

    assert_response :not_found
  end

  test "show requires authentication" do
    item = grocery_items(:smith_milk)

    get "/grocery_items/#{item.id}"

    assert_response :unauthorized
  end

  # POST /grocery_items
  test "create creates grocery item" do
    user = users(:john_smith)

    assert_difference("GroceryItem.count", 1) do
      post "/grocery_items",
        params: {
          data: {
            name: "New Item",
            quantity: 2,
            aisle: "produce",
            unit: "count",
            status: "pending"
          }
        },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :created
    json = response.parsed_body
    assert_equal "New Item", json["name"]
  end

  test "create validates required fields" do
    user = users(:john_smith)

    assert_no_difference("GroceryItem.count") do
      post "/grocery_items",
        params: {data: {name: ""}},
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :unprocessable_entity
  end

  test "create requires authentication" do
    post "/grocery_items",
      params: {data: {name: "Test"}},
      as: :json

    assert_response :unauthorized
  end

  # PUT /grocery_items/:id
  test "update updates grocery item" do
    user = users(:john_smith)
    item = grocery_items(:smith_milk)

    put "/grocery_items/#{item.id}",
      params: {
        data: {
          name: "Updated Item",
          quantity: 5,
          aisle: "dairy_eggs",
          unit: "l",
          status: "completed"
        }
      },
      headers: auth_headers_for(user),
      as: :json

    assert_response :ok
    json = response.parsed_body
    assert_equal "Updated Item", json["name"]
    assert_equal "completed", json["status"]
  end

  test "update returns 404 for other family's item" do
    user = users(:john_smith)
    other_item = GroceryItem.create!(
      family: families(:johnson_family),
      name: "Other Item",
      quantity: 1,
      aisle: :produce,
      unit: :count
    )

    put "/grocery_items/#{other_item.id}",
      params: {data: {name: "Hacked"}},
      headers: auth_headers_for(user),
      as: :json

    assert_response :not_found
  end

  test "update requires authentication" do
    item = grocery_items(:smith_milk)

    put "/grocery_items/#{item.id}",
      params: {data: {name: "Updated"}},
      as: :json

    assert_response :unauthorized
  end

  # DELETE /grocery_items/:id
  test "destroy deletes grocery item" do
    user = users(:john_smith)
    item = grocery_items(:smith_milk)

    assert_difference("GroceryItem.count", -1) do
      delete "/grocery_items/#{item.id}", headers: auth_headers_for(user)
    end

    assert_response :success
  end

  test "destroy returns 404 for other family's item" do
    user = users(:john_smith)
    other_item = GroceryItem.create!(
      family: families(:johnson_family),
      name: "Other Item",
      quantity: 1,
      aisle: :produce,
      unit: :count
    )

    assert_no_difference("GroceryItem.count") do
      delete "/grocery_items/#{other_item.id}", headers: auth_headers_for(user)
    end

    assert_response :not_found
  end

  test "destroy requires authentication" do
    item = grocery_items(:smith_milk)

    delete "/grocery_items/#{item.id}"

    assert_response :unauthorized
  end

  # POST /grocery_items/checkout
  test "checkout deletes completed items" do
    user = users(:john_smith)
    completed_item = GroceryItem.create!(
      family: user.family,
      name: "Completed",
      quantity: 1,
      aisle: :produce,
      unit: :count,
      status: :completed
    )
    pending_item = GroceryItem.create!(
      family: user.family,
      name: "Pending",
      quantity: 1,
      aisle: :produce,
      unit: :count,
      status: :pending
    )

    post "/grocery_items/checkout", headers: auth_headers_for(user)

    assert_response :success
    assert_not GroceryItem.exists?(completed_item.id)
    assert GroceryItem.exists?(pending_item.id)
  end

  test "checkout requires authentication" do
    post "/grocery_items/checkout"

    assert_response :unauthorized
  end

  # POST /grocery_items/generate
  test "generate creates items from schedule" do
    user = users(:john_smith)
    recipe = recipes(:pasta_carbonara_smith)

    # Create a schedule with the recipe
    schedule_day = ScheduleDay.create!(family: user.family, date: Date.today)
    ScheduleItem.create!(
      schedule_day: schedule_day,
      recipe: recipe,
      kind: :recipe,
      meal_type: :breakfast
    )

    ingredient_count = recipe.ingredients.count

    assert_difference("user.family.grocery_items.count", ingredient_count) do
      post "/grocery_items/generate",
        params: {start: Date.today.to_s, end: Date.today.to_s, ingredients: recipe.ingredients.map(&:id).map(&:to_s).index_with { 1 }},
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :success
  end

  test "generate aggregates same ingredients" do
    user = users(:john_smith)
    recipe = recipes(:pasta_carbonara_smith)

    # Create two schedule days with the same recipe
    date1 = Date.today + 10.days
    date2 = Date.today + 11.days
    schedule_day1 = ScheduleDay.create!(family: user.family, date: date1)
    schedule_day2 = ScheduleDay.create!(family: user.family, date: date2)

    ScheduleItem.create!(
      schedule_day: schedule_day1,
      recipe: recipe,
      kind: :recipe,
      meal_type: :breakfast
    )
    ScheduleItem.create!(
      schedule_day: schedule_day2,
      recipe: recipe,
      kind: :recipe,
      meal_type: :breakfast
    )

    ingredient_count = recipe.ingredients.count
    original_quantity = recipe.ingredients.first.quantity

    # Should create unique items, not duplicate
    assert_difference("user.family.grocery_items.count", ingredient_count) do
      post "/grocery_items/generate",
        params: {start: date1.to_s, end: date2.to_s, ingredients: recipe.ingredients.map(&:id).map(&:to_s).index_with { 1 }},
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :success

    # Check that quantities are aggregated (doubled in this case)
    grocery_item = GroceryItem.find_by(name: recipe.ingredients.first.name)
    assert_equal original_quantity * 2, grocery_item.quantity
  end

  test "generate requires start and end dates" do
    user = users(:john_smith)

    post "/grocery_items/generate",
      headers: auth_headers_for(user),
      as: :json

    assert_response :bad_request
  end

  test "generate requires authentication" do
    post "/grocery_items/generate",
      params: {start: Date.today.to_s, end: Date.today.to_s},
      as: :json

    assert_response :unauthorized
  end

  test "generate merges weight units" do
    user = users(:john_smith)
    recipe_a = recipes(:pasta_carbonara_smith)
    recipe_b = recipes(:scrambled_eggs_smith)

    # Create ingredient for recipe_a: Flour 500g
    flour_a = Ingredient.create!(
      recipe: recipe_a,
      name: "Flour",
      quantity: 500,
      unit: :g,
      aisle: :produce
    )

    # Create ingredient for recipe_b: Flour 300g
    flour_b = Ingredient.create!(
      recipe: recipe_b,
      name: "Flour",
      quantity: 300,
      unit: :g,
      aisle: :produce
    )

    # Schedule both recipes
    schedule_day = ScheduleDay.create!(family: user.family, date: Date.today)
    ScheduleItem.create!(schedule_day: schedule_day, recipe: recipe_a, kind: :recipe, meal_type: :breakfast)
    ScheduleItem.create!(schedule_day: schedule_day, recipe: recipe_b, kind: :recipe, meal_type: :lunch)

    assert_difference("user.family.grocery_items.count", 1) do
      post "/grocery_items/generate",
        params: {start: Date.today.to_s, end: Date.today.to_s, ingredients: {flour_a.id.to_s => 1, flour_b.id.to_s => 1}},
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :success
    grocery_item = GroceryItem.find_by(name: "Flour")
    assert_equal 800, grocery_item.quantity
    assert_equal "g", grocery_item.unit.to_s
  end

  test "generate keeps cross-category ingredients separate" do
    user = users(:john_smith)
    recipe_a = recipes(:pasta_carbonara_smith)
    recipe_b = recipes(:scrambled_eggs_smith)

    # Create ingredient for recipe_a: Avocado 200g (weight)
    avocado_a = Ingredient.create!(
      recipe: recipe_a,
      name: "Avocado",
      quantity: 200,
      unit: :g,
      aisle: :produce
    )

    # Create ingredient for recipe_b: Avocado 1 count
    avocado_b = Ingredient.create!(
      recipe: recipe_b,
      name: "Avocado",
      quantity: 1,
      unit: :count,
      aisle: :produce
    )

    # Schedule both recipes
    schedule_day = ScheduleDay.create!(family: user.family, date: Date.today)
    ScheduleItem.create!(schedule_day: schedule_day, recipe: recipe_a, kind: :recipe, meal_type: :breakfast)
    ScheduleItem.create!(schedule_day: schedule_day, recipe: recipe_b, kind: :recipe, meal_type: :lunch)

    post "/grocery_items/generate",
      params: {start: Date.today.to_s, end: Date.today.to_s, ingredients: {avocado_a.id.to_s => 1, avocado_b.id.to_s => 1}},
      headers: auth_headers_for(user),
      as: :json

    assert_response :success
    avocados = GroceryItem.where(name: "Avocado").order(:unit)
    assert_equal 2, avocados.count, "Expected 2 avocado items but got #{avocados.count}. Items: #{avocados.map { |a| "#{a.name} #{a.quantity}#{a.unit}" }.join(", ")}"
    assert_equal "count", avocados.last.unit.to_s
    assert_equal "g", avocados.first.unit.to_s
  end

  test "generate normalizes ingredient names" do
    user = users(:john_smith)
    recipe_a = recipes(:pasta_carbonara_smith)
    recipe_b = recipes(:scrambled_eggs_smith)

    # Create ingredient for recipe_a: Flour 500g
    flour_a = Ingredient.create!(
      recipe: recipe_a,
      name: "Flour",
      quantity: 500,
      unit: :g,
      aisle: :produce
    )

    # Create ingredient for recipe_b: flour 300g (lowercase)
    flour_b = Ingredient.create!(
      recipe: recipe_b,
      name: "flour",
      quantity: 300,
      unit: :g,
      aisle: :produce
    )

    # Schedule both recipes
    schedule_day = ScheduleDay.create!(family: user.family, date: Date.today)
    ScheduleItem.create!(schedule_day: schedule_day, recipe: recipe_a, kind: :recipe, meal_type: :breakfast)
    ScheduleItem.create!(schedule_day: schedule_day, recipe: recipe_b, kind: :recipe, meal_type: :lunch)

    assert_difference("user.family.grocery_items.count", 1) do
      post "/grocery_items/generate",
        params: {start: Date.today.to_s, end: Date.today.to_s, ingredients: {flour_a.id.to_s => 1, flour_b.id.to_s => 1}},
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :success
    grocery_item = GroceryItem.find_by(name: "Flour")
    assert_equal 800, grocery_item.quantity
  end

  test "generate converts to imperial for imperial user" do
    user = users(:john_smith)
    user.family.update!(unit_preference: :imperial) # imperial
    recipe = recipes(:pasta_carbonara_smith)

    # Create ingredient: Flour 100g
    flour = Ingredient.create!(
      recipe: recipe,
      name: "Flour",
      quantity: 100,
      unit: :g,
      aisle: :produce
    )

    # Schedule recipe
    schedule_day = ScheduleDay.create!(family: user.family, date: Date.today)
    ScheduleItem.create!(schedule_day: schedule_day, recipe: recipe, kind: :recipe, meal_type: :breakfast)

    assert_difference("user.family.grocery_items.count", 1) do
      post "/grocery_items/generate",
        params: {start: Date.today.to_s, end: Date.today.to_s, ingredients: {flour.id.to_s => 1}},
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :success
    grocery_item = GroceryItem.find_by(name: "Flour")
    assert_equal "oz", grocery_item.unit.to_s
  end

  # Display conversion tests
  test "show applies metric display conversion for metric user" do
    user = users(:john_smith)
    user.family.update!(unit_preference: :metric) # metric
    item = GroceryItem.create!(
      family: user.family,
      name: "Test Item",
      quantity: 1500,
      aisle: :produce,
      unit: :g,
      status: :pending
    )

    get "/grocery_items/#{item.id}", headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert_equal 1.5, json["quantity"]
    assert_equal "kg", json["unit"]
  end

  test "show applies imperial display conversion for imperial user" do
    user = users(:john_smith)
    user.family.update!(unit_preference: :imperial) # imperial
    item = GroceryItem.create!(
      family: user.family,
      name: "Test Item",
      quantity: 32,
      aisle: :produce,
      unit: :fl_oz,
      status: :pending
    )

    get "/grocery_items/#{item.id}", headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert_equal 1.0, json["quantity"]
    assert_equal "qt", json["unit"]
  end

  test "show applies spoon conversion for both systems" do
    user = users(:john_smith)
    user.family.update!(unit_preference: :metric) # metric
    item = GroceryItem.create!(
      family: user.family,
      name: "Test Item",
      quantity: 6,
      aisle: :produce,
      unit: :tsp,
      status: :pending
    )

    get "/grocery_items/#{item.id}", headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert_equal 2.0, json["quantity"]
    assert_equal "tbsp", json["unit"]
  end

  test "show preserves count unit" do
    user = users(:john_smith)
    user.family.update!(unit_preference: :metric) # metric
    item = GroceryItem.create!(
      family: user.family,
      name: "Test Item",
      quantity: 1,
      aisle: :produce,
      unit: :count,
      status: :pending
    )

    get "/grocery_items/#{item.id}", headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert_equal 1, json["quantity"]
    assert_equal "pc", json["unit"]
  end

  test "index applies display conversion for all items" do
    user = users(:john_smith)
    user.family.update!(unit_preference: :metric) # metric
    item1 = GroceryItem.create!(
      family: user.family,
      name: "Item 1",
      quantity: 1500,
      aisle: :produce,
      unit: :g,
      status: :pending
    )
    item2 = GroceryItem.create!(
      family: user.family,
      name: "Item 2",
      quantity: 6,
      aisle: :produce,
      unit: :tsp,
      status: :pending
    )

    get "/grocery_items", headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    item1_json = json.find { |j| j["id"] == item1.id.to_s }
    item2_json = json.find { |j| j["id"] == item2.id.to_s }
    assert_equal 1.5, item1_json["quantity"]
    assert_equal "kg", item1_json["unit"]
    assert_equal 2.0, item2_json["quantity"]
    assert_equal "tbsp", item2_json["unit"]
  end

  # GET /grocery_items/preview
  test "preview requires authentication" do
    get "/grocery_items/preview", params: {start: Date.today.to_s, end: Date.today.to_s}
    assert_response :unauthorized
  end

  test "preview requires start and end params" do
    user = users(:john_smith)
    get "/grocery_items/preview", headers: auth_headers_for(user)
    assert_response :bad_request
  end

  test "preview rejects invalid date format" do
    user = users(:john_smith)
    get "/grocery_items/preview", params: {start: "not-a-date", end: Date.today.to_s}, headers: auth_headers_for(user)
    assert_response :bad_request
    json = response.parsed_body
    assert json["error"].present?
  end

  test "preview returns empty array when no recipes scheduled" do
    user = users(:john_smith)
    get "/grocery_items/preview", params: {start: "2099-01-01", end: "2099-01-07"}, headers: auth_headers_for(user)
    assert_response :success
    json = response.parsed_body
    assert_equal [], json
  end

  test "preview returns recipes with correct structure" do
    user = users(:john_smith)
    recipe = recipes(:pasta_carbonara_smith)
    sd = ScheduleDay.create!(family: user.family, date: Date.today + 30.days)
    ScheduleItem.create!(schedule_day: sd, recipe: recipe, kind: :recipe, meal_type: :breakfast)

    get "/grocery_items/preview", params: {start: (Date.today + 30.days).to_s, end: (Date.today + 30.days).to_s}, headers: auth_headers_for(user)

    assert_response :success
    assert_equal [
      {
        "id" => recipe.id.to_s,
        "name" => "Pasta Carbonara",
        "meal_type" => "breakfast",
        "amount" => 1,
        "ingredients" => [
          {"id" => ingredients(:pasta_carbonara_eggs).id.to_s, "name" => "Eggs", "quantity" => 3, "unit" => "pcs"},
          {"id" => ingredients(:pasta_carbonara_pasta).id.to_s, "name" => "Spaghetti", "quantity" => 400, "unit" => "g"}
        ]
      }
    ], response.parsed_body
  end

  test "preview returns correct amount for repeated recipe" do
    user = users(:john_smith)
    recipe = recipes(:pasta_carbonara_smith)
    (Date.today + 40.days..Date.today + 42.days).each do |date|
      sd = ScheduleDay.create!(family: user.family, date: date)
      ScheduleItem.create!(schedule_day: sd, recipe: recipe, kind: :recipe, meal_type: :breakfast)
    end

    get "/grocery_items/preview", params: {start: (Date.today + 40.days).to_s, end: (Date.today + 42.days).to_s}, headers: auth_headers_for(user)

    assert_response :success
    assert_equal [
      {
        "id" => recipe.id.to_s,
        "name" => "Pasta Carbonara",
        "meal_type" => "breakfast",
        "amount" => 3,
        "ingredients" => [
          {"id" => ingredients(:pasta_carbonara_eggs).id.to_s, "name" => "Eggs", "quantity" => 3, "unit" => "pcs"},
          {"id" => ingredients(:pasta_carbonara_pasta).id.to_s, "name" => "Spaghetti", "quantity" => 400, "unit" => "g"}
        ]
      }
    ], response.parsed_body
  end

  test "preview returns display-converted ingredient quantities for metric family" do
    user = users(:john_smith)
    user.family.update!(unit_preference: :metric)
    recipe = recipes(:pasta_carbonara_smith)
    sd = ScheduleDay.create!(family: user.family, date: Date.today + 50.days)
    ScheduleItem.create!(schedule_day: sd, recipe: recipe, kind: :recipe, meal_type: :lunch)

    get "/grocery_items/preview", params: {start: (Date.today + 50.days).to_s, end: (Date.today + 50.days).to_s}, headers: auth_headers_for(user)

    assert_response :success
    assert_equal [
      {
        "id" => recipe.id.to_s,
        "name" => "Pasta Carbonara",
        "meal_type" => "lunch",
        "amount" => 1,
        "ingredients" => [
          {"id" => ingredients(:pasta_carbonara_eggs).id.to_s, "name" => "Eggs", "quantity" => 3, "unit" => "pcs"},
          {"id" => ingredients(:pasta_carbonara_pasta).id.to_s, "name" => "Spaghetti", "quantity" => 400, "unit" => "g"}
        ]
      }
    ], response.parsed_body
  end

  test "preview ingredient quantities are per single recipe not multiplied by amount" do
    user = users(:john_smith)
    recipe = recipes(:pasta_carbonara_smith)
    [Date.today + 60.days, Date.today + 61.days].each do |date|
      sd = ScheduleDay.create!(family: user.family, date: date)
      ScheduleItem.create!(schedule_day: sd, recipe: recipe, kind: :recipe, meal_type: :breakfast)
    end

    get "/grocery_items/preview", params: {start: (Date.today + 60.days).to_s, end: (Date.today + 61.days).to_s}, headers: auth_headers_for(user)

    assert_response :success
    # amount is 2 but ingredient quantities are still for ONE recipe — not doubled
    assert_equal [
      {
        "id" => recipe.id.to_s,
        "name" => "Pasta Carbonara",
        "meal_type" => "breakfast",
        "amount" => 2,
        "ingredients" => [
          {"id" => ingredients(:pasta_carbonara_eggs).id.to_s, "name" => "Eggs", "quantity" => 3, "unit" => "pcs"},
          {"id" => ingredients(:pasta_carbonara_pasta).id.to_s, "name" => "Spaghetti", "quantity" => 400, "unit" => "g"}
        ]
      }
    ], response.parsed_body
  end

  test "preview excludes dining out schedule items" do
    user = users(:john_smith)
    schedule_day = ScheduleDay.create!(family: user.family, date: Date.today + 70.days)
    ScheduleItem.create!(schedule_day: schedule_day, kind: :dining_out, dining_out_name: "Pizza Place", meal_type: :dinner)

    get "/grocery_items/preview", params: {start: (Date.today + 70.days).to_s, end: (Date.today + 70.days).to_s}, headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert_equal [], json
  end

  test "preview isolates to current family" do
    user = users(:john_smith)
    other_recipe = recipes(:grilled_salmon_johnson)
    other_family = families(:johnson_family)
    sd = ScheduleDay.create!(family: other_family, date: Date.today + 80.days)
    ScheduleItem.create!(schedule_day: sd, recipe: other_recipe, kind: :recipe, meal_type: :dinner)

    get "/grocery_items/preview", params: {start: (Date.today + 80.days).to_s, end: (Date.today + 80.days).to_s}, headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert_equal [], json
  end

  test "preview returns imperial display units for imperial family" do
    user = users(:john_smith)
    user.family.update!(unit_preference: :imperial)
    recipe = recipes(:pasta_carbonara_smith)
    sd = ScheduleDay.create!(family: user.family, date: Date.today + 85.days)
    ScheduleItem.create!(schedule_day: sd, recipe: recipe, kind: :recipe, meal_type: :dinner)

    get "/grocery_items/preview", params: {start: (Date.today + 85.days).to_s, end: (Date.today + 85.days).to_s}, headers: auth_headers_for(user)

    assert_response :success
    # 400g → 400 * 0.035274 = 14.1096 oz → round_oz (≥4 → ceil) = 15.0 oz
    assert_equal [
      {
        "id" => recipe.id.to_s,
        "name" => "Pasta Carbonara",
        "meal_type" => "dinner",
        "amount" => 1,
        "ingredients" => [
          {"id" => ingredients(:pasta_carbonara_eggs).id.to_s, "name" => "Eggs", "quantity" => 3, "unit" => "pcs"},
          {"id" => ingredients(:pasta_carbonara_pasta).id.to_s, "name" => "Spaghetti", "quantity" => 15.0, "unit" => "oz"}
        ]
      }
    ], response.parsed_body
  end
end
