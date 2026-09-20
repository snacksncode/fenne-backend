require "test_helper"

class V2PurchaseSuggestionsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john_smith)
    @product = Product.create!(family: @user.family, name: "Preview flour", aisle: :pantry,
      unit: :g, pack_sizes: [200, 500])
  end

  test "projects pack purchases from draft stock without writing pantry or groceries" do
    entry = PantryEntry.create!(family: @user.family, product: @product, quantity_remaining: 50, last_acquired: Time.current)
    assert_no_difference(["PantryEntry.count", "GroceryItem.count"]) do
      get "/v2/products/#{@product.id}/purchase_suggestion", params: { needed: 800, pantry: 100 },
        headers: auth_headers_for(@user)
    end
    assert_response :success
    assert_equal "success", response.parsed_body["status"]
    assert_equal({ "needed" => 800.0, "pantry" => 100.0, "shortage" => 700.0,
      "suggested_quantity" => 700.0,
      "packs" => [{ "size" => 500.0, "count" => 1 }, { "size" => 200.0, "count" => 1 }] }, response.parsed_body["data"])
    assert_equal 50, entry.reload.quantity_remaining
  end

  test "draft zero stock overrides real stock and covered counts buy nothing" do
    @product.update!(unit: :count, pack_sizes: [])
    PantryEntry.create!(family: @user.family, product: @product, quantity_remaining: 28, last_acquired: Time.current)
    get "/v2/products/#{@product.id}/purchase_suggestion", params: { needed: 13, pantry: 0 }, headers: auth_headers_for(@user)
    assert_response :success
    assert_equal 13, response.parsed_body.dig("data", "suggested_quantity")
    get "/v2/products/#{@product.id}/purchase_suggestion", params: { needed: 13, pantry: 28 }, headers: auth_headers_for(@user)
    assert_response :success
    assert_equal 0, response.parsed_body.dig("data", "suggested_quantity")
  end

  test "invalid draft quantities have structured errors" do
    [{ needed: -1, pantry: 0 }, { needed: 1, pantry: -1 }, { needed: 1, pantry: "abc" },
      { needed: 1, pantry: 1_000_000_001 }, { needed: 1 }].each do |params|
      get "/v2/products/#{@product.id}/purchase_suggestion", params: params, headers: auth_headers_for(@user)
      assert_response :unprocessable_entity
      assert_equal "error", response.parsed_body["status"]
      assert response.parsed_body["errors"].key?(params[:needed] == -1 ? "needed" : "pantry")
    end
  end

  test "cannot project another family's product" do
    get "/v2/products/#{@product.id}/purchase_suggestion", params: { needed: 1, pantry: 0 },
      headers: auth_headers_for(users(:bob_johnson))
    assert_response :not_found
  end

  test "reminders and kitchen basics do not expose stock calculations" do
    [{ reminder_frequency_value: 1, reminder_frequency_unit: :months },
      { reminder_frequency_value: nil, reminder_frequency_unit: nil, is_kitchen_basic: true }].each do |attrs|
      @product.update!(attrs.merge(pack_sizes: []))
      get "/v2/products/#{@product.id}/purchase_suggestion", params: { needed: 1, pantry: 0 }, headers: auth_headers_for(@user)
      assert_response :unprocessable_entity
      assert response.parsed_body.dig("errors", "base").present?
    end
  end
end
