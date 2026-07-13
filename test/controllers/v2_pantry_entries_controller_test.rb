require "test_helper"

class V2PantryEntriesControllerTest < ActionDispatch::IntegrationTest
  test "create adds to existing pantry entry for product" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Rice", aisle: :pantry, unit: :count)
    entry = PantryEntry.create!(family: user.family, product: product, quantity_remaining: 1, last_acquired: 2.days.ago)

    assert_no_difference("PantryEntry.count") do
      post "/v2/pantry_entries",
        params: { product_id: product.id, quantity_remaining: 4 },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :success
    assert_equal 5.0, entry.reload.quantity_remaining.to_f
    assert entry.last_acquired > 1.minute.ago
  end

  test "create uses supplied last acquired timestamp" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Beans", aisle: :pantry, unit: :count)
    acquired_at = "2026-04-20T12:30:00Z"

    post "/v2/pantry_entries",
      params: { product_id: product.id, quantity_remaining: 2, last_acquired: acquired_at },
      headers: auth_headers_for(user),
      as: :json

    assert_response :created
    entry = PantryEntry.find_by!(product: product)
    assert_equal 2.0, entry.quantity_remaining.to_f
    assert_equal Time.zone.iso8601(acquired_at), entry.last_acquired
  end

  test "create refreshes timed product without stock quantity" do
    user = users(:john_smith)
    product = Product.create!(
      family: user.family,
      name: "Olive Oil",
      aisle: :pantry,
      unit: :count,
      reminder_frequency_value: 2,
      reminder_frequency_unit: :months
    )
    entry = PantryEntry.create!(family: user.family, product: product, quantity_remaining: 0, last_acquired: 2.months.ago)

    assert_no_difference("PantryEntry.count") do
      post "/v2/pantry_entries",
        params: { product_id: product.id, quantity_remaining: 9 },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :success
    assert_equal 0.0, entry.reload.quantity_remaining.to_f
    assert entry.last_acquired > 1.minute.ago
  end

  test "create rejects kitchen basic products" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Salt", aisle: :spices_baking, unit: :count, is_kitchen_basic: true)

    assert_no_difference("PantryEntry.count") do
      post "/v2/pantry_entries",
        params: { product_id: product.id, quantity_remaining: 1 },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :unprocessable_entity
  end

  test "create rejects invalid last acquired timestamp" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Pasta", aisle: :pantry, unit: :count)

    assert_no_difference("PantryEntry.count") do
      post "/v2/pantry_entries",
        params: { product_id: product.id, quantity_remaining: 1, last_acquired: "not-a-date" },
        headers: auth_headers_for(user),
        as: :json
    end

    assert_response :unprocessable_entity
  end

  test "update keeps timed product stock quantity at zero" do
    user = users(:john_smith)
    product = Product.create!(
      family: user.family,
      name: "Olive Oil",
      aisle: :pantry,
      unit: :count,
      reminder_frequency_value: 2,
      reminder_frequency_unit: :months
    )
    entry = PantryEntry.create!(family: user.family, product: product, quantity_remaining: 0, last_acquired: 2.months.ago)

    patch "/v2/pantry_entries/#{entry.id}",
      params: { quantity_remaining: 9 },
      headers: auth_headers_for(user),
      as: :json

    assert_response :success
    assert_equal 0.0, entry.reload.quantity_remaining.to_f
  end

end
