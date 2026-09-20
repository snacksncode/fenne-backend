require "test_helper"

class PurchaseSuggestionTest < ActiveSupport::TestCase
  def proposal(needed, sizes, pantry: 0, unit: :g)
    product = Product.new(unit: unit, pack_sizes: sizes)
    PurchaseSuggestion.call(product: product, needed: needed, pantry: pantry)
  end

  test "pesto rounds purchase but retains exact requirement" do
    result = proposal(40, [190])
    assert_equal 40, result[:needed]
    assert_equal 190, result[:suggested_quantity]
    assert_equal [{size: 190.0, count: 1}], result[:packs]
  end

  test "subtract pantry before selecting chicken packs" do
    result = proposal(750, [500], pantry: 250)
    assert_equal 500, result[:shortage]
    assert_equal 500, result[:suggested_quantity]
  end

  test "minimize excess then pack count including mixed sizes" do
    assert_equal [{size: 400.0, count: 2}], proposal(750, [400, 700])[:packs]
    assert_equal [{size: 700.0, count: 1}, {size: 400.0, count: 1}], proposal(1100, [400, 700])[:packs]
    assert_equal [{size: 800.0, count: 1}], proposal(750, [400, 800])[:packs]
    assert_equal 1200, proposal(1150, [400, 700])[:suggested_quantity]
  end

  test "equivalent units and fractional pack sizes" do
    result = proposal(0.75, [0.4, 0.7], unit: :kg)
    assert_in_delta 0.8, result[:suggested_quantity]
    assert_equal 2, result[:packs].first[:count]
  end

  test "loose purchases and sufficient stock" do
    assert_equal 40.25, proposal(40.25, [])[:suggested_quantity]
    result = proposal(40, [190], pantry: 100)
    assert_equal 0, result[:suggested_quantity]
    assert_empty result[:packs]
  end

  test "matches exhaustive solutions for small pack combinations" do
    [ [4, 7], [3, 5, 8], [6, 9, 20] ].each do |sizes|
      (1..45).each do |target|
        possibilities = [0].product(*Array.new(sizes.length) { (0..16).to_a }).filter_map do |row|
          counts = row.drop(1)
          total = counts.zip(sizes).sum { |count, size| count * size }
          [total, counts.sum] if total >= target
        end
        expected = possibilities.min
        result = proposal(target, sizes)
        assert_equal expected, [result[:suggested_quantity].to_i, result[:packs].sum { |pack| pack[:count] }]
      end
    end
  end
end
