require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "quantity cannot be used with count unit" do
    product = Product.new(
      family: families(:smith_family),
      name: "Eggs",
      aisle: :dairy_eggs,
      quantity: 12,
      unit: :count
    )

    assert_not product.valid?
    assert_includes product.errors[:quantity], "cannot be used with count unit"
  end

  test "count unit without quantity is counted" do
    product = Product.new(
      family: families(:smith_family),
      name: "Eggs",
      aisle: :dairy_eggs,
      unit: :count
    )

    assert product.valid?
    assert product.counted?
    assert_equal :counted, product.shape
  end

  test "quantity with measured unit is measured" do
    product = Product.new(
      family: families(:smith_family),
      name: "Sour Cream",
      aisle: :dairy_eggs,
      quantity: 200,
      unit: :g
    )

    assert product.valid?
    assert product.measured?
    assert_equal :measured, product.shape
  end
end
