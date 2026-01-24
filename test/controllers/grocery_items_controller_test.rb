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

    assert_difference("GroceryItem.count", ingredient_count) do
      post "/grocery_items/generate",
           params: {start: Date.today.to_s, end: Date.today.to_s},
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
    assert_difference("GroceryItem.count", ingredient_count) do
      post "/grocery_items/generate",
           params: {start: date1.to_s, end: date2.to_s},
           headers: auth_headers_for(user),
           as: :json
    end

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
end
