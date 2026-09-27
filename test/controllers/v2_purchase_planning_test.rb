require "test_helper"

class V2PurchasePlanningTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john_smith)
    @product = Product.create!(family: @user.family, name: "Test Pesto", aisle: :pantry, unit: :g, pack_sizes: [190])
    @recipe = Recipe.create!(family: @user.family, name: "Pesto Pasta", meal_types: [:dinner], time_in_minutes: 10)
    @recipe.ingredients.create!(product: @product, quantity: 40, unit: :g)
    day = ScheduleDay.create!(family: @user.family, date: Date.current)
    ScheduleItem.create!(schedule_day: day, kind: :recipe, meal_type: :dinner, recipe: @recipe)
    @dates = { start: Date.current.iso8601, end: Date.current.iso8601 }
  end

  def generate(extra = {})
    post "/v2/grocery_items/generate", params: @dates.merge(checked_product_ids: [@product.id]).merge(extra), headers: auth_headers_for(@user), as: :json
    assert_response :success
    GroceryItem.find_by!(product: @product)
  end

  def read_item(item)
    get "/v2/grocery_items/#{item.id}", headers: auth_headers_for(@user)
    assert_response :success
    response.parsed_body.fetch("data")
  end

  test "pantry covered measured demand does not appear as a zero purchase on the grocery list" do
    @product.update!(pack_sizes: [])
    @recipe.ingredients.first.update!(quantity: 200)
    PantryEntry.create!(family: @user.family, product: @product, quantity_remaining: 450, last_acquired: Time.current)
    generate

    get "/v2/grocery_items", headers: auth_headers_for(@user)
    assert_response :success
    assert_not response.parsed_body.fetch("data").any? { |row| row.dig("product", "id") == @product.id.to_s },
      "A covered recipe must not leave an uncheckable 0 g purchase on the grocery list"

    2.times { generate }
    get "/v2/grocery_items", headers: auth_headers_for(@user)
    row = response.parsed_body.fetch("data").find { |item| item.dig("product", "id") == @product.id.to_s }
    assert_not_nil row, "Accumulated demand must still appear when it exceeds pantry stock"
    assert_equal 150, row["quantity"]
    assert_equal 600, row.dig("purchase", "needed")
  end

  test "grocery list uses current pantry while preserving explicit and checked purchases" do
    item = generate
    pantry = PantryEntry.create!(family: @user.family, product: @product, quantity_remaining: 100, last_acquired: Time.current)
    get "/v2/grocery_items", headers: auth_headers_for(@user)
    assert_not response.parsed_body.fetch("data").any? { |row| row["id"] == item.id.to_s }

    pantry.update!(quantity_remaining: 0)
    get "/v2/grocery_items", headers: auth_headers_for(@user)
    assert response.parsed_body.fetch("data").any? { |row| row["id"] == item.id.to_s && row["quantity"] == 190 }

    pantry.update!(quantity_remaining: 100)
    item.update!(quantity: 120, quantity_overridden: true)
    get "/v2/grocery_items", headers: auth_headers_for(@user)
    assert response.parsed_body.fetch("data").any? { |row| row["id"] == item.id.to_s && row["quantity"] == 120 }

    item.update!(quantity: 190, quantity_overridden: false, status: :completed)
    get "/v2/grocery_items", headers: auth_headers_for(@user)
    assert response.parsed_body.fetch("data").any? { |row| row["id"] == item.id.to_s && row["quantity"] == 190 }
  end

  test "direct recipe additions covered by pantry do not appear as zero purchases" do
    PantryEntry.create!(family: @user.family, product: @product, quantity_remaining: 100, last_acquired: Time.current)
    post "/v2/grocery_items/from_recipe", params: {recipe_id: @recipe.id}, headers: auth_headers_for(@user), as: :json
    assert_response :created
    get "/v2/grocery_items", headers: auth_headers_for(@user)
    assert_not response.parsed_body.fetch("data").any? { |row| row.dig("product", "id") == @product.id.to_s }
  end

  test "repeated generation adds demand not rounded packs and GET uses current pantry" do
    item = generate
    generate
    data = read_item(item)
    assert_equal 80, data.dig("purchase", "needed")
    assert_equal 190, data["quantity"]
    PantryEntry.create!(family: @user.family, product: @product, quantity_remaining: 100, last_acquired: Time.current)
    data = read_item(item)
    assert_equal 100, data.dig("purchase", "pantry")
    assert_equal 0, data["quantity"]
    assert_equal 190, item.reload.quantity # GET never writes a suggestion.
  end

  test "generation preview includes covered requirements and combined existing demand" do
    generate
    PantryEntry.create!(family: @user.family, product: @product, quantity_remaining: 100, last_acquired: Time.current)
    get "/v2/grocery_items/preview", params: @dates, headers: auth_headers_for(@user)
    assert_response :success
    row = response.parsed_body.dig("data", "products").find { |r| r["product_id"] == @product.id.to_s }
    assert_equal 80, row.dig("purchase", "needed")
    assert_equal 0, row["quantity"]
  end

  test "generation override survives pantry changes and can return to suggestion" do
    item = generate(purchase_quantities: [{ product_id: @product.id, quantity: 120 }])
    PantryEntry.create!(family: @user.family, product: @product, quantity_remaining: 100, last_acquired: Time.current)
    data = read_item(item)
    assert_equal 120, data["quantity"]
    assert_equal true, data["quantity_overridden"]
    patch "/v2/grocery_items/#{item.id}", params: {use_suggestion: true}, headers: auth_headers_for(@user), as: :json
    assert_response :success
    assert_equal 0, response.parsed_body.dig("data", "quantity")
  end

  test "preview explains the recipes behind combined demand" do
    item = generate
    earlier = Recipe.create!(family: @user.family, name: "Earlier pesto meal", meal_types: [:dinner], time_in_minutes: 10)
    item.update!(recipe_ids: [earlier.id])
    get "/v2/grocery_items/preview", params: @dates, headers: auth_headers_for(@user)
    assert_response :success
    row = response.parsed_body.dig("data", "products").find { |r| r["product_id"] == @product.id.to_s }
    assert_equal [earlier.id.to_s, @recipe.id.to_s].sort, row.fetch("recipes").map { |r| r["id"] }.sort
  end

  test "counted generation uses the chosen amount without pack calculations" do
    @product.update!(unit: :count, pack_sizes: [])
    @recipe.ingredients.first.update!(unit: :count, quantity: 2)
    generate(purchase_quantities: [{ product_id: @product.id, quantity: 6 }])
    item = generate
    assert_equal 8, item.quantity
    assert_nil read_item(item)["purchase"]
    post "/v2/grocery_items/generate", params: @dates.merge(checked_product_ids: [@product.id], purchase_quantities: [{ product_id: @product.id, quantity: 0 }]), headers: auth_headers_for(@user), as: :json
    assert_response :success
    assert_equal 8, item.reload.quantity
  end

  test "preview keeps pantry covered counted items with recipe and pantry quantities" do
    @product.update!(unit: :count, pack_sizes: [])
    @recipe.ingredients.first.update!(unit: :count, quantity: 13)
    PantryEntry.create!(family: @user.family, product: @product, quantity_remaining: 28, last_acquired: Time.current)

    get "/v2/grocery_items/preview", params: @dates, headers: auth_headers_for(@user)
    assert_response :success
    row = response.parsed_body.dig("data", "products").find { |r| r["product_id"] == @product.id.to_s }
    assert_not_nil row, "Pantry-covered count items must remain visible in review"
    assert_equal 13, row.dig("purchase", "needed")
    assert_equal 28, row.dig("purchase", "pantry")
    assert_equal 0, row["quantity"]
    assert_equal [], row.dig("purchase", "packs")
    assert_equal [@recipe.id.to_s], row.fetch("recipes").map { |recipe| recipe["id"] }

    assert_no_difference "GroceryItem.count" do
      post "/v2/grocery_items/generate", params: @dates.merge(checked_product_ids: [@product.id]), headers: auth_headers_for(@user), as: :json
      assert_response :success
    end
  end

  test "count preview uses current pantry on every fetch and permits buying extra" do
    @product.update!(unit: :count, pack_sizes: [])
    @recipe.ingredients.first.update!(unit: :count, quantity: 13)
    pantry = PantryEntry.create!(family: @user.family, product: @product, quantity_remaining: 5, last_acquired: Time.current)

    get "/v2/grocery_items/preview", params: @dates, headers: auth_headers_for(@user)
    assert_response :success
    row = response.parsed_body.dig("data", "products").find { |r| r["product_id"] == @product.id.to_s }
    assert_equal 13, row.dig("purchase", "needed")
    assert_equal 5, row.dig("purchase", "pantry")
    assert_equal 8, row["quantity"]

    pantry.update!(quantity_remaining: 28)
    get "/v2/grocery_items/preview", params: @dates, headers: auth_headers_for(@user)
    row = response.parsed_body.dig("data", "products").find { |r| r["product_id"] == @product.id.to_s }
    assert_not_nil row
    assert_equal 28, row.dig("purchase", "pantry")
    assert_equal 0, row["quantity"]
    assert_equal 2, generate(purchase_quantities: [{ product_id: @product.id, quantity: 2 }]).quantity
  end

  test "checking freezes displayed purchase and checkout deposits it" do
    item = generate
    patch "/v2/grocery_items/#{item.id}", params: {status: "completed", quantity: 190}, headers: auth_headers_for(@user), as: :json
    assert_response :success
    PantryEntry.create!(family: @user.family, product: @product, quantity_remaining: 100, last_acquired: Time.current)
    assert_equal 190, read_item(item)["quantity"]
    post "/v2/grocery_items/checkout", headers: auth_headers_for(@user)
    assert_response :success
    assert_equal 290, @product.pantry_entries.first.quantity_remaining
  end

  test "explicit edits to checked measured purchases are allowed" do
    item = generate
    item.update!(status: :completed)
    patch "/v2/grocery_items/#{item.id}", params: {quantity: 120}, headers: auth_headers_for(@user), as: :json
    assert_response :success
    assert_equal 120, item.reload.quantity
    assert item.quantity_overridden
  end

  test "direct recipe additions combine demand and preserve manual purchases" do
    2.times do
      post "/v2/grocery_items/from_recipe", params: {recipe_id: @recipe.id}, headers: auth_headers_for(@user), as: :json
      assert_response :success
    end
    item = GroceryItem.find_by!(product: @product)
    assert_equal 80, item.needed_quantity
    assert_equal 190, read_item(item)["quantity"]
    patch "/v2/grocery_items/#{item.id}", params: {quantity: 300}, headers: auth_headers_for(@user), as: :json
    generate
    assert_equal 300, read_item(item)["quantity"]
  end

  test "pack size validation and compatible unit change" do
    patch "/v2/products/#{@product.id}", params: {pack_sizes: [0, -10]}, headers: auth_headers_for(@user), as: :json
    assert_response :unprocessable_entity
    patch "/v2/products/#{@product.id}", params: {unit: "kg"}, headers: auth_headers_for(@user), as: :json
    assert_response :success
    assert_equal [0.19], response.parsed_body.dig("data", "pack_sizes")
  end

  test "counted products reject packaging and legacy packaging is not revived" do
    post "/v2/products", params: {name: "Counted Test", aisle: "pantry", unit: "count", pack_sizes: [6]}, headers: auth_headers_for(@user), as: :json
    assert_response :unprocessable_entity
    @product.update_columns(quantity: 900, pack_count: 4, pack_sizes: [])
    item = generate
    assert_equal 40, read_item(item)["quantity"]
  end
  test "checkout retains a shortage when chosen purchase is below demand" do
    item = generate
    patch "/v2/grocery_items/#{item.id}", params: {quantity: 20}, headers: auth_headers_for(@user), as: :json
    patch "/v2/grocery_items/#{item.id}", params: {status: "completed", quantity: 20}, headers: auth_headers_for(@user), as: :json
    post "/v2/grocery_items/checkout", headers: auth_headers_for(@user)
    assert_response :success
    assert_equal 20, @product.pantry_entries.first.quantity_remaining
    assert_equal "pending", item.reload.status
    assert_equal 20, read_item(item).dig("purchase", "shortage")
  end

  test "zero override skips pantry writes at checkout" do
    item = generate(purchase_quantities: [{product_id: @product.id, quantity: 0}])
    patch "/v2/grocery_items/#{item.id}", params: {status: "completed", quantity: 0}, headers: auth_headers_for(@user), as: :json
    assert_no_difference "PantryEntry.count" do
      post "/v2/grocery_items/checkout", headers: auth_headers_for(@user)
    end
    assert_response :success
  end

  test "existing grocery quantities remain fixed without reconstructed demand" do
    item = GroceryItem.create!(family: @user.family, product: @product, name: @product.name,
      unit: :g, aisle: :pantry, quantity: 40, source: :generated)
    PantryEntry.create!(family: @user.family, product: @product, quantity_remaining: 100, last_acquired: Time.current)
    data = read_item(item)
    assert_equal 40, data["quantity"]
    assert_nil data["purchase"]
    assert item.quantity_overridden
  end

  test "older clients can create edit generate and check without new fields" do
    post "/v2/products", params: {name: "Old client flour", aisle: "pantry", unit: "g"}, headers: auth_headers_for(@user), as: :json
    assert_response :success
    assert_equal [], response.parsed_body.dig("data", "pack_sizes")
    patch "/v2/products/#{@product.id}", params: {name: "Pesto renamed"}, headers: auth_headers_for(@user), as: :json
    assert_response :success
    assert_equal [190], @product.reload.pack_sizes
    item = generate
    patch "/v2/grocery_items/#{item.id}", params: {status: "completed"}, headers: auth_headers_for(@user), as: :json
    assert_response :success
    assert_equal 190, item.reload.quantity
  end

end
