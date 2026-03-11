require "test_helper"

class UnitConverterTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # category()
  # ---------------------------------------------------------------------------

  test "category returns :weight for all weight units" do
    assert_equal :weight, UnitConverter.category(:g)
    assert_equal :weight, UnitConverter.category(:kg)
    assert_equal :weight, UnitConverter.category(:oz)
    assert_equal :weight, UnitConverter.category(:lb)
  end

  test "category returns :fluid for all fluid units" do
    assert_equal :fluid, UnitConverter.category(:ml)
    assert_equal :fluid, UnitConverter.category(:l)
    assert_equal :fluid, UnitConverter.category(:fl_oz)
    assert_equal :fluid, UnitConverter.category(:cup)
    assert_equal :fluid, UnitConverter.category(:qt)
  end

  test "category returns :spoon for spoon units" do
    assert_equal :spoon, UnitConverter.category(:tbsp)
    assert_equal :spoon, UnitConverter.category(:tsp)
  end

  test "category returns :count for count" do
    assert_equal :count, UnitConverter.category(:count)
  end

  # ---------------------------------------------------------------------------
  # to_base() — metric system (base units: g, ml, tsp, count)
  # ---------------------------------------------------------------------------

  test "to_base converts metric weight units to grams" do
    assert_equal [1.0, :g], UnitConverter.to_base(1, :g, :metric)
    assert_equal [1000.0, :g], UnitConverter.to_base(1, :kg, :metric)
    assert_equal [28.3495, :g], UnitConverter.to_base(1, :oz, :metric)
    assert_equal [453.592, :g], UnitConverter.to_base(1, :lb, :metric)
  end

  test "to_base converts metric fluid units to ml" do
    assert_equal [1.0, :ml], UnitConverter.to_base(1, :ml, :metric)
    assert_equal [1000.0, :ml], UnitConverter.to_base(1, :l, :metric)
    assert_equal [29.5735, :ml], UnitConverter.to_base(1, :fl_oz, :metric)
    assert_equal [236.588, :ml], UnitConverter.to_base(1, :cup, :metric)
    assert_equal [946.353, :ml], UnitConverter.to_base(1, :qt, :metric)
  end

  test "to_base converts metric spoon units to tsp" do
    assert_equal [1.0, :tsp], UnitConverter.to_base(1, :tsp, :metric)
    assert_equal [3.0, :tsp], UnitConverter.to_base(1, :tbsp, :metric)
  end

  test "to_base converts metric count to count" do
    assert_equal [1.0, :count], UnitConverter.to_base(1, :count, :metric)
  end

  test "to_base scales quantity correctly (metric)" do
    result = UnitConverter.to_base(2.5, :kg, :metric)
    assert_equal :g, result[1]
    assert_in_delta 2500.0, result[0], 0.001
  end

  # ---------------------------------------------------------------------------
  # to_base() — imperial system (base units: oz, fl_oz, tsp, count)
  # ---------------------------------------------------------------------------

  test "to_base converts imperial weight units to oz" do
    assert_equal [1.0, :oz], UnitConverter.to_base(1, :oz, :imperial)
    assert_equal [16.0, :oz], UnitConverter.to_base(1, :lb, :imperial)
    assert_equal [0.035274, :oz], UnitConverter.to_base(1, :g, :imperial)
    assert_equal [35.274, :oz], UnitConverter.to_base(1, :kg, :imperial)
  end

  test "to_base converts imperial fluid units to fl_oz" do
    assert_equal [1.0, :fl_oz], UnitConverter.to_base(1, :fl_oz, :imperial)
    assert_equal [8.0, :fl_oz], UnitConverter.to_base(1, :cup, :imperial)
    assert_equal [32.0, :fl_oz], UnitConverter.to_base(1, :qt, :imperial)
    assert_equal [0.033814, :fl_oz], UnitConverter.to_base(1, :ml, :imperial)
    assert_equal [33.814, :fl_oz], UnitConverter.to_base(1, :l, :imperial)
  end

  test "to_base converts imperial spoon units to tsp" do
    assert_equal [1.0, :tsp], UnitConverter.to_base(1, :tsp, :imperial)
    assert_equal [3.0, :tsp], UnitConverter.to_base(1, :tbsp, :imperial)
  end

  test "to_base converts imperial count to count" do
    assert_equal [1.0, :count], UnitConverter.to_base(1, :count, :imperial)
  end

  # ---------------------------------------------------------------------------
  # round_g() — 1g / 5g / 50g / 100g tiers
  # ---------------------------------------------------------------------------

  test "round_g uses correct step size per magnitude tier" do
    assert_equal 3, UnitConverter.round_g(2.9)   # <10: 1g steps (ceil)
    assert_equal 15, UnitConverter.round_g(12)    # 10–99: 5g steps
    assert_equal 50, UnitConverter.round_g(47)    # 10–99: 5g steps
    assert_equal 95, UnitConverter.round_g(93)    # 10–99: 5g steps
    assert_equal 150, UnitConverter.round_g(120)   # 100–499: 50g steps
    assert_equal 500, UnitConverter.round_g(480)   # 100–499: 50g steps
    assert_equal 1000, UnitConverter.round_g(950)   # ≥500: 100g steps → cascade trigger
  end

  # ---------------------------------------------------------------------------
  # round_kg() — 0.1 kg steps
  # ---------------------------------------------------------------------------

  test "round_kg uses 0.1 kg steps without IEEE 754 drift" do
    assert_equal 1.0, UnitConverter.round_kg(1.0)
    assert_equal 1.1, UnitConverter.round_kg(1.05)
    assert_equal 1.2, UnitConverter.round_kg(1.13)
    assert_equal 2.4, UnitConverter.round_kg(2.35)
  end

  # ---------------------------------------------------------------------------
  # round_ml() — mirrors round_g tiers
  # ---------------------------------------------------------------------------

  test "round_ml uses correct step size per magnitude tier" do
    assert_equal 3, UnitConverter.round_ml(2.9)
    assert_equal 15, UnitConverter.round_ml(12)
    assert_equal 50, UnitConverter.round_ml(47)
    assert_equal 95, UnitConverter.round_ml(93)
    assert_equal 150, UnitConverter.round_ml(120)
    assert_equal 500, UnitConverter.round_ml(480)
    assert_equal 1000, UnitConverter.round_ml(950)
  end

  # ---------------------------------------------------------------------------
  # round_l() — mirrors round_kg (0.1 l steps)
  # ---------------------------------------------------------------------------

  test "round_l uses 0.1 l steps without IEEE 754 drift" do
    assert_equal 1.0, UnitConverter.round_l(1.0)
    assert_equal 1.1, UnitConverter.round_l(1.05)
    assert_equal 1.2, UnitConverter.round_l(1.13)
    assert_equal 2.4, UnitConverter.round_l(2.35)
  end

  # ---------------------------------------------------------------------------
  # round_oz() — 0.5 oz below 4, 1 oz at and above 4
  # ---------------------------------------------------------------------------

  test "round_oz uses 0.5 oz steps below 4 and 1 oz steps at 4 and above" do
    assert_equal 1.5, UnitConverter.round_oz(1.3)  # <4: 0.5 steps
    assert_equal 4.0, UnitConverter.round_oz(3.9)  # <4: rounds up to 4.0
    assert_equal 5.0, UnitConverter.round_oz(4.1)  # ≥4: 1 oz steps
    assert_equal 10.0, UnitConverter.round_oz(10)   # ≥4: exact integer
  end

  # ---------------------------------------------------------------------------
  # round_lb() — 0.25 lb steps
  # ---------------------------------------------------------------------------

  test "round_lb uses 0.25 lb steps" do
    assert_equal 1.0, UnitConverter.round_lb(1.0)
    assert_equal 1.25, UnitConverter.round_lb(1.1)
    assert_equal 1.75, UnitConverter.round_lb(1.6)
  end

  # ---------------------------------------------------------------------------
  # round_fl_oz() — 0.5 fl oz steps
  # ---------------------------------------------------------------------------

  test "round_fl_oz uses 0.5 fl oz steps" do
    assert_equal 7.5, UnitConverter.round_fl_oz(7.4)
    assert_equal 8.0, UnitConverter.round_fl_oz(7.6)  # cascade trigger value
  end

  # ---------------------------------------------------------------------------
  # friendly() — metric weight cascade (:g → :kg at 1000)
  # ---------------------------------------------------------------------------

  test "friendly metric weight stays in grams below 1000" do
    assert_equal [500.0, :g], UnitConverter.friendly(500, :g, :metric)
  end

  test "friendly metric weight cascades to kg at exactly 1000g" do
    assert_equal [1.0, :kg], UnitConverter.friendly(1000, :g, :metric)
  end

  test "friendly metric weight cascades to kg above 1000g" do
    assert_equal [1.5, :kg], UnitConverter.friendly(1500, :g, :metric)
  end

  # ---------------------------------------------------------------------------
  # friendly() — metric fluid cascade (:ml → :l at 1000)
  # ---------------------------------------------------------------------------

  test "friendly metric fluid stays in ml below 1000" do
    assert_equal [500.0, :ml], UnitConverter.friendly(500, :ml, :metric)
  end

  test "friendly metric fluid cascades to l at exactly 1000ml" do
    assert_equal [1.0, :l], UnitConverter.friendly(1000, :ml, :metric)
  end

  # ---------------------------------------------------------------------------
  # friendly() — spoon cascade (:tsp → :tbsp at 3)
  # ---------------------------------------------------------------------------

  test "friendly metric spoon stays in tsp below 3" do
    assert_equal [2.0, :tsp], UnitConverter.friendly(2, :tsp, :metric)
  end

  test "friendly metric spoon cascades to tbsp at exactly 3 tsp" do
    assert_equal [1.0, :tbsp], UnitConverter.friendly(3, :tsp, :metric)
  end

  test "friendly imperial spoon stays in tsp below 3" do
    assert_equal [2.0, :tsp], UnitConverter.friendly(2, :tsp, :imperial)
  end

  test "friendly imperial spoon cascades to tbsp at exactly 3 tsp" do
    assert_equal [1.0, :tbsp], UnitConverter.friendly(3, :tsp, :imperial)
  end

  # ---------------------------------------------------------------------------
  # friendly() — imperial weight cascade (:oz → :lb at 16)
  # ---------------------------------------------------------------------------

  test "friendly imperial weight stays in oz below 16" do
    assert_equal [10.0, :oz], UnitConverter.friendly(10, :oz, :imperial)
  end

  test "friendly imperial weight cascades to lb above 16 oz" do
    assert_equal [5.0, :lb], UnitConverter.friendly(80, :oz, :imperial)
  end

  # ---------------------------------------------------------------------------
  # friendly() — imperial fluid 3-level cascade (:fl_oz → :cup at 8 → :qt at 32)
  # ---------------------------------------------------------------------------

  test "friendly imperial fluid stays in fl oz below 8" do
    assert_equal [4.0, :fl_oz], UnitConverter.friendly(4, :fl_oz, :imperial)
  end

  test "friendly imperial fluid cascades to cup at exactly 8 fl oz" do
    assert_equal [1.0, :cup], UnitConverter.friendly(8, :fl_oz, :imperial)
  end

  test "friendly imperial fluid cascades to qt above 32 fl oz" do
    assert_equal [5.0, :qt], UnitConverter.friendly(160, :fl_oz, :imperial)
  end

  # ---------------------------------------------------------------------------
  # friendly() — count (no cascade)
  # ---------------------------------------------------------------------------

  test "friendly count returns integer with count symbol" do
    assert_equal [5, :count], UnitConverter.friendly(5, :count, :metric)
    assert_equal [5, :count], UnitConverter.friendly(5, :count, :imperial)
  end

  # ---------------------------------------------------------------------------
  # friendly() — round-first cascade behaviour
  # ---------------------------------------------------------------------------

  # 7.6 fl oz rounds to 8.0 fl oz, which >= 8 threshold → 1 cup (not "8 fl oz")
  test "friendly cascades fl_oz to cup when rounding hits threshold" do
    assert_equal [1.0, :cup], UnitConverter.friendly(7.6, :fl_oz, :imperial)
  end

  # 2.8 tsp rounds to 3.0, which >= 3 → 1 tbsp
  test "friendly cascades tsp to tbsp when rounding hits threshold" do
    assert_equal [1.0, :tbsp], UnitConverter.friendly(2.8, :tsp, :metric)
    assert_equal [1.0, :tbsp], UnitConverter.friendly(2.8, :tsp, :imperial)
  end

  # 950g rounds to 1000g → cascades to 1 kg
  test "friendly cascades g to kg when rounding hits 1000" do
    assert_equal [1.0, :kg], UnitConverter.friendly(950, :g, :metric)
  end

  # 1100g → round_g(1100) = 1100 → kg: round_kg(1.1) = 1.1 (NOT 1.5 — using 0.1 steps)
  test "friendly kg uses 0.1 steps not 0.5" do
    assert_equal [1.1, :kg], UnitConverter.friendly(1100, :g, :metric)
  end

  # 15 fl oz → round to 15.0 → >= 8 → cup: 15/8=1.875 → round_cup = 2.0
  test "friendly rounds cascaded cup value" do
    assert_equal [2.0, :cup], UnitConverter.friendly(15, :fl_oz, :imperial)
  end

  # ---------------------------------------------------------------------------
  # pretty_unit() — human-readable labels
  # ---------------------------------------------------------------------------

  test "pretty_unit returns pc for count of 1" do
    assert_equal "pc", UnitConverter.pretty_unit(1, :count)
  end

  test "pretty_unit returns pcs for count greater than 1" do
    assert_equal "pcs", UnitConverter.pretty_unit(3, :count)
    assert_equal "pcs", UnitConverter.pretty_unit(5, :count)
  end

  test "pretty_unit returns fl oz string for :fl_oz" do
    assert_equal "fl oz", UnitConverter.pretty_unit(2.0, :fl_oz)
  end

  test "pretty_unit returns symbol string for all other units" do
    assert_equal "kg", UnitConverter.pretty_unit(1.5, :kg)
    assert_equal "g", UnitConverter.pretty_unit(400, :g)
    assert_equal "qt", UnitConverter.pretty_unit(1.0, :qt)
  end
end
