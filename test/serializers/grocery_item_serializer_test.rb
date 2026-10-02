require "test_helper"

class GroceryItemSerializerTest < ActiveSupport::TestCase
  test "batch rendering loads missing recipe attribution once and preserves unknown names" do
    family = families(:smith_family)
    recipe = family.recipes.create!(name: "Deleted recipe", meal_types: [ :dinner ], time_in_minutes: 10)
    items = 5.times.map do |index|
      product = family.products.create!(name: "Attribution product #{index}", aisle: :pantry, unit: :count)
      GroceryItem.add_product!(family: family, product: product, quantity: 1,
        source: "generated", recipe_ids: [ recipe.id ])
    end
    recipe.destroy!
    items = family.grocery_items.detail.where(id: items.map(&:id)).order(:id).to_a
    rows = nil

    recipe_queries = count_recipe_queries do
      rows = GroceryItemSerializer.render_many(items)
    end

    assert_equal items.map { |item| item.id.to_s }, rows.map { |row| row.fetch(:id) }
    assert rows.all? { |row| row.fetch(:quantity) == 1.0 }
    assert rows.all? { |row| row.fetch(:recipes) == [ { id: recipe.id.to_s, name: "Unknown recipe" } ] }
    assert_equal 1, recipe_queries, "missing attributed Recipes should still use the single batch query"
  end

  test "single rendering loads family scoped recipe names when no batch index is supplied" do
    family = families(:smith_family)
    recipe = recipes(:scrambled_eggs_smith)
    other_recipe = families(:johnson_family).recipes.first
    product = family.products.create!(name: "Attributed product", aisle: :pantry, unit: :count)
    item = GroceryItem.add_product!(family: family, product: product, quantity: 2,
      source: "generated", recipe_ids: [ recipe.id, other_recipe.id ])

    row = GroceryItemSerializer.render(item)

    assert_equal [
      { id: recipe.id.to_s, name: recipe.name },
      { id: other_recipe.id.to_s, name: "Unknown recipe" }
    ], row.fetch(:recipes)
  end

  private

  def count_recipe_queries
    count = 0
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      count += 1 if payload[:sql].match?(/\ASELECT\b.*\bFROM "recipes"/i)
    end
    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
    end
    count
  end
end
