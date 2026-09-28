require "test_helper"

class V2ProductCatalogControllerTest < ActionDispatch::IntegrationTest
  test "returns the complete family catalog and suggestions without a query" do
    user = users(:john_smith)
    35.times do |index|
      Product.create!(family: user.family, name: "Catalog Product #{index}", aisle: :produce, unit: :count)
    end
    basic = Product.create!(family: user.family, name: "Salt", aisle: :spices_baking, unit: :count, is_kitchen_basic: true)
    suggestion = ProductSuggestion.create!(name: "Salt", aisle: :spices_baking)

    get "/v2/product_catalog", headers: auth_headers_for(user)

    assert_response :success
    assert_equal "success", response.parsed_body["status"]
    data = response.parsed_body.fetch("data")
    assert_equal user.family.products.count, data.fetch("products").size
    assert_equal user.family.products.pluck(:id).map(&:to_s).sort, data.fetch("products").map { |p| p["id"] }.sort
    assert_equal true, data.fetch("products").find { |p| p["id"] == basic.id.to_s }["is_kitchen_basic"]
    assert_includes data.fetch("suggestions").map { |s| s["id"] }, suggestion.id.to_s
    assert data.fetch("products").all? { |p| p.key?("conversions") && p.key?("unit") && p.key?("shape") }
  end

  test "does not expose products belonging to another family" do
    user = users(:john_smith)
    get "/v2/product_catalog", headers: auth_headers_for(user)

    assert_response :success
    ids = response.parsed_body.dig("data", "products").map { |p| p["id"] }
    families(:johnson_family).products.each { |product| assert_not_includes ids, product.id.to_s }
  end

  test "a refetch reflects edits and deletions" do
    user = users(:john_smith)
    product = Product.create!(family: user.family, name: "Dragonfruit", aisle: :produce, unit: :count)
    product.update!(name: "Passionfruit")
    get "/v2/product_catalog", headers: auth_headers_for(user)
    assert_includes response.parsed_body.dig("data", "products").map { |p| p["name"] }, "Passionfruit"

    product.destroy!
    get "/v2/product_catalog", headers: auth_headers_for(user)
    assert_not_includes response.parsed_body.dig("data", "products").map { |p| p["id"] }, product.id.to_s
  end

  test "requires authentication" do
    get "/v2/product_catalog"

    assert_response :unauthorized
    assert_equal "error", response.parsed_body["status"]
    assert response.parsed_body.key?("errors")
  end
end
