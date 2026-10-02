require "test_helper"

class GroceryListCheckoutTest < ActiveSupport::TestCase
  setup do
    @family = families(:smith_family)
  end

  test "a later invalid purchase rolls back earlier Pantry writes and Grocery List removals" do
    first = purchase("Rice", quantity: 500)
    pantry = PantryEntry.create!(family: @family, product: first.product,
      quantity_remaining: 100, last_acquired: 2.days.ago)
    acquired = pantry.last_acquired
    invalid = purchase("Flour", quantity: 250)
    # Model validation prevents new invalid data; Checkout must also remain
    # atomic if existing data cannot be accepted by the Pantry writer.
    invalid.update_columns(quantity: -1)

    assert_raises(ArgumentError) { GroceryListCheckout.call(family: @family) }

    assert_equal 100, pantry.reload.quantity_remaining
    assert_equal acquired, pantry.last_acquired
    assert first.reload.status_completed?
    assert invalid.reload.status_completed?
    assert_nil PantryEntry.find_by(product: invalid.product)
  end

  test "only this Family's checked purchases are transferred" do
    checked = purchase("Rice", quantity: 500)
    pending = purchase("Flour", quantity: 250, status: :pending)
    other = purchase("Other rice", quantity: 100, family: families(:johnson_family))

    GroceryListCheckout.call(family: @family)

    assert_not GroceryItem.exists?(checked.id)
    assert_equal 500, PantryEntry.find_by!(product: checked.product).quantity_remaining
    assert pending.reload.status_pending?
    assert other.reload.status_completed?
    assert_nil PantryEntry.find_by(product: pending.product)
    assert_nil PantryEntry.find_by(product: other.product)
  end

  private

  def purchase(name, quantity:, family: @family, status: :completed)
    product = family.products.create!(name: name, aisle: :pantry, unit: :g)
    family.grocery_items.create!(product: product, name: name, aisle: product.aisle,
      unit: product.unit, quantity: quantity, status: status)
  end
end
