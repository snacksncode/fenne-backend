require "test_helper"

class V2GroceryItemsControllerTest < ActionDispatch::IntegrationTest
  test "manual add increments existing active row for the same product" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Eggs", aisle: :dairy_eggs, unit: :count)
    GroceryItem.create!(
      family: user.family,
      product: product,
      name: product.name,
      aisle: product.aisle,
      unit: product.unit,
      quantity: 2,
      status: :pending
    )

    assert_no_difference("GroceryItem.count") do
      post "/v2/grocery_items",
        params: { type: "product", product_id: product.id, quantity: 3, unit: "count" },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :created
    assert_equal 5.0, GroceryItem.find_by(product: product).quantity.to_f
  end

  test "manual add rejects incompatible units for counted product" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Eggs", aisle: :dairy_eggs, unit: :count)

    assert_no_difference("GroceryItem.count") do
      post "/v2/grocery_items",
        params: { type: "product", product_id: product.id, quantity: 300, unit: "g" },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :unprocessable_entity
    assert_equal [ "incompatible unit" ], response.parsed_body.dig("errors", "base")
  end

  test "manual add stores product quantity exactly in the product unit" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Sour Cream", aisle: :dairy_eggs, quantity: 200, unit: :g)

    post "/v2/grocery_items",
      params: { type: "product", product_id: product.id, quantity: 50, unit: "g" },
      headers: auth_headers_for(user),
      as: :json

    assert_response :created
    assert_equal 50.0, GroceryItem.find_by!(product: product).quantity.to_f
  end

  test "manual add to completed product row reopens it as pending" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Eggs", aisle: :dairy_eggs, unit: :count)
    item = GroceryItem.create!(
      family: user.family,
      product: product,
      name: product.name,
      aisle: product.aisle,
      unit: product.unit,
      quantity: 2,
      status: :completed
    )

    assert_no_difference("GroceryItem.count") do
      post "/v2/grocery_items",
        params: { type: "product", product_id: product.id, quantity: 3, unit: "count" },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :created
    assert_equal 5.0, item.reload.quantity.to_f
    assert_equal "pending", item.status
  end

  test "manual add allows custom productless grocery rows" do
    user = users(:john_smith)

    assert_difference("GroceryItem.count", 1) do
      post "/v2/grocery_items",
        params: { type: "custom", name: "Cleaning products", aisle: "household", quantity: 1, unit: "count" },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :created
    item = GroceryItem.find_by!(family: user.family, name: "Cleaning products")
    assert_nil item.product_id
    assert_equal "household", item.aisle
    assert_equal 1.0, item.quantity.to_f
  end

  test "manual add allows kitchen basics on the grocery list" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Salt", aisle: :spices_baking, unit: :count, is_kitchen_basic: true)

    assert_difference("GroceryItem.count", 1) do
      post "/v2/grocery_items",
        params: { type: "product", product_id: product.id, quantity: 1, unit: "count" },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :created
    assert_equal 1.0, GroceryItem.find_by!(product: product).quantity.to_f
  end

  test "manual add requires product id for product rows" do
    user = users(:john_smith)

    assert_no_difference("GroceryItem.count") do
      post "/v2/grocery_items",
        params: { type: "product", quantity: 1, unit: "count" },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :unprocessable_entity
    assert_equal [ "is required" ], response.parsed_body.dig("errors", "product_id")
  end

  test "manual add cannot use another family's product" do
    user = users(:john_smith)
    product = Product.create!(family: families(:johnson_family), name: "Other Rice", aisle: :pantry, unit: :count)

    assert_no_difference("GroceryItem.count") do
      post "/v2/grocery_items",
        params: { type: "product", product_id: product.id, quantity: 1, unit: "count" },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :not_found
  end

  test "checkout adds completed measured item into pantry and clears shopping row" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Rice", aisle: :pantry, quantity: 500, unit: :g)
    item = GroceryItem.create!(
      family: user.family,
      product: product,
      name: product.name,
      aisle: product.aisle,
      unit: product.unit,
      quantity: 500,
      status: :completed
    )

    post "/v2/grocery_items/checkout", headers: auth_headers_for(user)

    assert_response :success
    assert_not GroceryItem.exists?(item.id)
    assert_equal 500.0, PantryEntry.find_by(product: product).quantity_remaining.to_f
  end

  test "checkout clears completed custom rows without adding pantry stock" do
    user = users(:john_smith)
    item = GroceryItem.create!(
      family: user.family,
      name: "Cleaning Products",
      aisle: :household,
      unit: :count,
      quantity: 1,
      status: :completed
    )

    assert_no_difference("PantryEntry.count") do
      post "/v2/grocery_items/checkout", headers: auth_headers_for(user)
    end

    assert_response :success
    assert_not GroceryItem.exists?(item.id)
    assert_nil Product.find_by(family: user.family, name: "Cleaning Products")
  end

  test "checkout stamps last acquired for existing counted pantry entries" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Eggs", aisle: :dairy_eggs, unit: :count)
    entry = PantryEntry.create!(
      family: user.family,
      product: product,
      quantity_remaining: 1,
      last_acquired: 3.days.ago
    )
    GroceryItem.create!(
      family: user.family,
      product: product,
      name: product.name,
      aisle: product.aisle,
      unit: product.unit,
      quantity: 2,
      status: :completed
    )

    post "/v2/grocery_items/checkout", headers: auth_headers_for(user)

    assert_response :success
    assert_equal 3.0, entry.reload.quantity_remaining.to_f
    assert entry.last_acquired > 1.minute.ago
  end

  test "checkout clears completed kitchen basics without adding pantry stock" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Salt", aisle: :spices_baking, unit: :count, is_kitchen_basic: true)
    item = GroceryItem.create!(
      family: user.family,
      product: product,
      name: product.name,
      aisle: product.aisle,
      unit: product.unit,
      quantity: 1,
      status: :completed
    )

    assert_no_difference(-> { PantryEntry.where(product: product).count }) do
      post "/v2/grocery_items/checkout", headers: auth_headers_for(user)
    end

    assert_response :success
    assert_not GroceryItem.exists?(item.id)
  end

  test "completed grocery rows reject quantity edits" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Milk", aisle: :dairy_eggs, unit: :count)
    item = GroceryItem.create!(
      family: user.family,
      product: product,
      name: product.name,
      aisle: product.aisle,
      unit: product.unit,
      quantity: 1,
      status: :completed
    )

    patch "/v2/grocery_items/#{item.id}",
      params: { quantity: 2, unit: "count" },
      headers: auth_headers_for(user),
      as: :json

    assert_response :unprocessable_entity
    assert_equal 1.0, item.reload.quantity.to_f
  end

  test "generate accepts checked product ids and creates product-backed grocery rows" do
    user = users(:john_smith)
    recipe = recipes(:scrambled_eggs_smith)
    product = Product.create!(family: user.family, name: "Eggs", aisle: :dairy_eggs, unit: :count)
    ingredients(:scrambled_eggs_eggs).update!(product: product)
    schedule_day = ScheduleDay.create!(family: user.family, date: Date.current, is_shopping_day: false)
    ScheduleItem.create!(schedule_day: schedule_day, kind: :recipe, meal_type: :breakfast, recipe: recipe)

    assert_difference("GroceryItem.count", 1) do
      post "/v2/grocery_items/generate",
        params: {
          start_date: Date.current.iso8601,
          end_date: Date.current.iso8601,
          checked_product_ids: [ product.id ]
        },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :success
    item = GroceryItem.find_by!(product: product)
    assert_equal 2.0, item.quantity.to_f
    assert_equal [ recipe.id ], item.recipe_ids
  end

  test "show resolves generated grocery item recipes through the item family" do
    user = users(:john_smith)
    recipe = recipes(:scrambled_eggs_smith)
    product = Product.create!(family: user.family, name: "Eggs", aisle: :dairy_eggs, unit: :count)
    item = GroceryItem.create!(
      family: user.family,
      product: product,
      name: product.name,
      aisle: product.aisle,
      unit: product.unit,
      quantity: 2,
      source: :generated,
      recipe_ids: [ recipe.id ]
    )

    get "/v2/grocery_items/#{item.id}", headers: auth_headers_for(user)

    assert_response :success
    assert_equal [ { "id" => recipe.id.to_s, "name" => recipe.name } ], response.parsed_body.dig("data", "recipes")
  end

  test "preview returns independent running low timed products unchecked" do
    user = users(:john_smith)
    product = Product.create!(
      family: user.family,
      name: "Olive Oil",
      aisle: :pantry,
      unit: :count,
      reminder_frequency_value: 2,
      reminder_frequency_unit: :months
    )
    PantryEntry.create!(family: user.family, product: product, quantity_remaining: 0, last_acquired: 2.months.ago)

    get "/v2/grocery_items/preview",
      params: { start_date: Date.current.iso8601, end_date: Date.current.iso8601 },
      headers: auth_headers_for(user)

    assert_response :success
    row = response.parsed_body.dig("data", "products").find { |product_row| product_row["product_id"] == product.id.to_s }
    assert_equal true, row["running_low"]
    assert_equal false, row["checked"]
  end

  test "generate can add checked independent running low timed products" do
    user = users(:john_smith)
    product = Product.create!(
      family: user.family,
      name: "Olive Oil",
      aisle: :pantry,
      unit: :count,
      reminder_frequency_value: 2,
      reminder_frequency_unit: :months
    )
    PantryEntry.create!(family: user.family, product: product, quantity_remaining: 0, last_acquired: 2.months.ago)

    assert_difference("GroceryItem.count", 1) do
      post "/v2/grocery_items/generate",
        params: {
          start_date: Date.current.iso8601,
          end_date: Date.current.iso8601,
          checked_product_ids: [ product.id ]
        },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :success
    item = GroceryItem.find_by!(product: product)
    assert_equal 1.0, item.quantity.to_f
    assert_equal [], item.recipe_ids
  end
end
