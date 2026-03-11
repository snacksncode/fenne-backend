require "test_helper"

class GroceryItemTest < ActiveSupport::TestCase
  test "status enum has pending and completed options" do
    item = grocery_items(:smith_milk)

    item.status = :pending
    assert item.status_pending?
    assert_not item.status_completed?

    item.status = :completed
    assert item.status_completed?
    assert_not item.status_pending?
  end

  test "unit enum includes all unit types" do
    item = grocery_items(:smith_milk)

    %i[g kg ml l fl_oz cup tbsp tsp qt oz lb count].each do |unit_type|
      item.unit = unit_type
      assert_equal unit_type.to_s, item.unit
    end
  end

  test "aisle enum includes all aisle types" do
    item = grocery_items(:smith_milk)

    %i[produce bakery dairy_eggs meat seafood pantry frozen_foods beverages
      snacks condiments_sauces spices_baking household personal_care
      pet_supplies other].each do |aisle_type|
      item.aisle = aisle_type
      assert_equal aisle_type.to_s, item.aisle
    end
  end

  test "validates name presence" do
    item = GroceryItem.new(
      family: families(:smith_family),
      quantity: 1,
      aisle: :produce,
      unit: :count
    )

    assert_not item.valid?
    assert_includes item.errors[:name], "can't be blank"
  end

  test "validates quantity presence" do
    item = GroceryItem.new(
      family: families(:smith_family),
      name: "Test Item",
      aisle: :produce,
      unit: :count
    )

    assert_not item.valid?
    assert_includes item.errors[:quantity], "can't be blank"
  end

  test "validates aisle presence" do
    item = GroceryItem.new(
      family: families(:smith_family),
      name: "Test Item",
      quantity: 1,
      unit: :count
    )

    assert_not item.valid?
    assert_includes item.errors[:aisle], "can't be blank"
  end

  test "validates unit presence" do
    item = GroceryItem.new(
      family: families(:smith_family),
      name: "Test Item",
      quantity: 1,
      aisle: :produce
    )

    assert_not item.valid?
    assert_includes item.errors[:unit], "can't be blank"
  end

  test "validates quantity is greater than 0" do
    item = GroceryItem.new(
      family: families(:smith_family),
      name: "Test Item",
      quantity: 0,
      aisle: :produce,
      unit: :count
    )

    assert_not item.valid?
    assert_includes item.errors[:quantity], "must be greater than 0"
  end

  test "allows positive quantity" do
    item = GroceryItem.new(
      family: families(:smith_family),
      name: "Test Item",
      quantity: 1,
      aisle: :produce,
      unit: :count
    )

    assert item.valid?
  end

  test "belongs to family" do
    item = grocery_items(:smith_milk)

    assert_instance_of Family, item.family
    assert_equal families(:smith_family), item.family
  end

  test "valid with all required attributes" do
    item = GroceryItem.new(
      family: families(:smith_family),
      name: "Apples",
      quantity: 5,
      aisle: :produce,
      unit: :count,
      status: :pending
    )

    assert item.valid?
  end
end
