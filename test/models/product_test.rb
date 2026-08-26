require "test_helper"

class ProductTest < ActiveSupport::TestCase
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

  test "non-count unit is measured without a package quantity" do
    product = Product.new(
      family: families(:smith_family),
      name: "Sour Cream",
      aisle: :dairy_eggs,
      unit: :g
    )

    assert product.valid?
    assert product.measured?
    assert_equal :measured, product.shape
  end

  test "reminder and kitchen basic modes cannot retain a measured unit" do
    reminder = Product.new(
      family: families(:smith_family),
      name: "Coffee",
      aisle: :pantry,
      unit: :g,
      reminder_frequency_value: 2,
      reminder_frequency_unit: :weeks
    )
    kitchen_basic = Product.new(
      family: families(:smith_family),
      name: "Salt",
      aisle: :spices_baking,
      unit: :g,
      is_kitchen_basic: true
    )

    assert_not reminder.valid?
    assert_not kitchen_basic.valid?
    assert_includes reminder.errors[:base], "tracking modes are mutually exclusive"
    assert_includes kitchen_basic.errors[:base], "tracking modes are mutually exclusive"
  end

  test "reminder and kitchen basic modes are mutually exclusive for count products" do
    product = Product.new(
      family: families(:smith_family),
      name: "Salt",
      aisle: :spices_baking,
      unit: :count,
      reminder_frequency_value: 2,
      reminder_frequency_unit: :weeks,
      is_kitchen_basic: true
    )

    assert_not product.valid?
    assert_includes product.errors[:base], "tracking modes are mutually exclusive"
  end
end
