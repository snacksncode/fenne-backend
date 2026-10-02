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

  test "undo batches product reads without preloading pantry entries that the writer reloads" do
    user = users(:john_smith)
    first = user.family.products.create!(name: "Undo first", aisle: :pantry, unit: :count)
    second = user.family.products.create!(name: "Undo second", aisle: :pantry, unit: :count)
    acquired_at = 2.days.ago.change(usec: 0)
    [ first, second ].each do |product|
      user.family.pantry_entries.create!(product: product, quantity_remaining: 10, last_acquired: acquired_at)
    end
    log = user.family.consumption_logs.create!(recipe_name: "Repeated ingredients", meal_type: :dinner,
      schedule_date: Date.current, deductions: [ deduction(first, 2), deduction(second, 3), deduction(first, 4) ])
    headers = auth_headers_for(user)

    queries = capture_select_queries do
      delete "/v2/consumption_logs/#{log.id}", headers: headers
    end

    assert_response :success
    assert_equal "success", response.parsed_body["status"]
    assert_not Family.find(user.family_id).consumption_logs.exists?(log.id)
    assert_equal 16, user.family.pantry_entries.find_by!(product: first).quantity_remaining
    assert_equal 13, user.family.pantry_entries.find_by!(product: second).quantity_remaining
    assert user.family.pantry_entries.where(product: [ first, second ]).all? { |entry| entry.last_acquired == acquired_at }
    product_reads = queries.count { |query| query.match?(/\bFROM "products"/) }
    pantry_loads = queries.count { |query| query.match?(/\ASELECT "pantry_entries"\.\* FROM/) }
    assert_operator product_reads, :<=, 4,
      "one Product batch plus at most one validation read per deduction (Product reads: #{product_reads}, Pantry loads: #{pantry_loads})"
    assert_equal 3, pantry_loads, "the writer must read current Pantry stock once per deduction: #{pantry_loads}"
  end

  test "undo recreates exhausted stock for repeated snapshots and skips foreign or deleted products" do
    user = users(:john_smith)
    product = user.family.products.create!(name: "Exhausted stock", aisle: :pantry, unit: :count)
    foreign_product = families(:johnson_family).products.first
    deleted_product = user.family.products.create!(name: "Deleted stock", aisle: :pantry, unit: :count)
    snapshots = [
      deduction(product, 2),
      deduction(product, 3).merge(product_id: product.id.to_s),
      deduction(foreign_product, 4),
      deduction(deleted_product, 1)
    ]
    deleted_product.destroy!
    log = user.family.consumption_logs.create!(recipe_name: "Missing ingredients", meal_type: :dinner,
      schedule_date: Date.current, deductions: snapshots)

    assert_difference("PantryEntry.count", 1) do
      delete "/v2/consumption_logs/#{log.id}", headers: auth_headers_for(user)
    end

    assert_response :success
    assert_equal 5, user.family.pantry_entries.find_by!(product: product).quantity_remaining
    assert_equal "Some pantry quantities could not be restored", response.parsed_body.dig("meta", "warning")
    assert_not user.family.pantry_entries.exists?(product: foreign_product)
    assert_not ConsumptionLog.exists?(log.id)
  end

  private

  def deduction(product, quantity)
    { product_id: product.id, actually_deducted: quantity.to_s, product_shape: product.shape.to_s, product_unit: product.unit }
  end

  def capture_select_queries
    queries = []
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      queries << payload[:sql] if payload[:name] != "SCHEMA" && payload[:sql].match?(/\ASELECT\b/i)
    end
    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
    end
    queries
  end
end
