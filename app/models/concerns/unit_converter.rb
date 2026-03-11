module UnitConverter
  CATEGORIES = {
    g: :weight, kg: :weight, oz: :weight, lb: :weight,
    ml: :fluid, l: :fluid, fl_oz: :fluid, cup: :fluid, qt: :fluid,
    tbsp: :spoon, tsp: :spoon,
    count: :count
  }.freeze

  # Factors to convert each unit TO its metric base (g, ml, tsp, count)
  METRIC_FACTORS = {
    g: 1.0, kg: 1000.0, oz: 28.3495, lb: 453.592,
    ml: 1.0, l: 1000.0, fl_oz: 29.5735, cup: 236.588, qt: 946.353,
    tsp: 1.0, tbsp: 3.0,
    count: 1.0
  }.freeze

  # Factors to convert each unit TO its imperial base (oz, fl_oz, tsp, count)
  IMPERIAL_FACTORS = {
    g: 0.035274, kg: 35.274, oz: 1.0, lb: 16.0,
    ml: 0.033814, l: 33.814, fl_oz: 1.0, cup: 8.0, qt: 32.0,
    tsp: 1.0, tbsp: 3.0,
    count: 1.0
  }.freeze

  METRIC_BASE_UNIT = {
    weight: :g,
    fluid: :ml,
    spoon: :tsp,
    count: :count
  }.freeze

  IMPERIAL_BASE_UNIT = {
    weight: :oz,
    fluid: :fl_oz,
    spoon: :tsp,
    count: :count
  }.freeze

  # Returns :weight, :fluid, :spoon, or :count
  def self.category(unit)
    CATEGORIES[unit]
  end

  # Converts quantity in `unit` to the system's base unit.
  # Returns [converted_quantity, base_unit_symbol]
  def self.to_base(quantity, unit, system)
    cat = category(unit)
    factors = (system == :metric) ? METRIC_FACTORS : IMPERIAL_FACTORS
    base_units = (system == :metric) ? METRIC_BASE_UNIT : IMPERIAL_BASE_UNIT

    converted = quantity * factors[unit]
    base_unit = base_units[cat]
    [converted, base_unit]
  end

  # 1g steps below 10, 5g steps 10–99, 50g steps 100–499, 100g steps ≥500
  def self.round_g(qty)
    if qty < 10
      qty.ceil
    elsif qty < 100
      (qty / 5.0).ceil * 5
    elsif qty < 500
      (qty / 50.0).ceil * 50
    else
      (qty / 100.0).ceil * 100
    end
  end

  # 0.1 kg steps — use Ruby's built-in Float#ceil(ndigits) to avoid IEEE 754 drift
  def self.round_kg(qty)
    qty.ceil(1)
  end

  # Same tiers as g: 1ml / 5ml / 50ml / 100ml
  def self.round_ml(qty)
    if qty < 10
      qty.ceil
    elsif qty < 100
      (qty / 5.0).ceil * 5
    elsif qty < 500
      (qty / 50.0).ceil * 50
    else
      (qty / 100.0).ceil * 100
    end
  end

  # 0.1 l steps
  def self.round_l(qty)
    qty.ceil(1)
  end

  # 0.5 oz below 4, 1 oz at and above 4
  def self.round_oz(qty)
    if qty < 4
      (qty * 2).ceil / 2.0
    else
      qty.ceil.to_f
    end
  end

  # 0.25 lb steps
  def self.round_lb(qty)
    (qty * 4).ceil / 4.0
  end

  # 0.5 fl oz steps
  def self.round_fl_oz(qty)
    (qty * 2).ceil / 2.0
  end

  # 0.25 cup steps
  def self.round_cup(qty)
    (qty * 4).ceil / 4.0
  end

  # 0.25 qt steps
  def self.round_qt(qty)
    (qty * 4).ceil / 4.0
  end

  # 0.25 tsp steps (¼ tsp is the smallest real kitchen measurement)
  def self.round_tsp(qty)
    (qty * 4).ceil / 4.0
  end

  # 0.5 tbsp steps
  def self.round_tbsp(qty)
    (qty * 2).ceil / 2.0
  end

  # Integer ceil, minimum 1
  def self.round_count(qty)
    [qty.ceil, 1].max
  end

  # Returns a display-friendly [quantity, unit_string] pair.
  # Rounds base unit FIRST, then checks cascade threshold on the rounded value,
  # then rounds in the target unit. This ensures e.g. 7.6 fl oz → 8.0 → cup.
  def self.friendly(quantity, base_unit, system)
    if system == :metric
      case base_unit
      when :g
        rounded = round_g(quantity)
        if rounded >= 1000
          [round_kg(rounded / 1000.0), "kg"]
        else
          [rounded, "g"]
        end
      when :ml
        rounded = round_ml(quantity)
        if rounded >= 1000
          [round_l(rounded / 1000.0), "l"]
        else
          [rounded, "ml"]
        end
      when :tsp
        rounded = round_tsp(quantity)
        if rounded >= 3
          [round_tbsp(rounded / 3.0), "tbsp"]
        else
          [rounded, "tsp"]
        end
      else # :count
        [round_count(quantity), "count"]
      end
    else # imperial
      case base_unit
      when :oz
        rounded = round_oz(quantity)
        if rounded >= 16
          [round_lb(rounded / 16.0), "lb"]
        else
          [rounded, "oz"]
        end
      when :fl_oz
        rounded = round_fl_oz(quantity)
        if rounded >= 32
          [round_qt(rounded / 32.0), "qt"]
        elsif rounded >= 8
          [round_cup(rounded / 8.0), "cup"]
        else
          [rounded, "fl oz"]
        end
      when :tsp
        rounded = round_tsp(quantity)
        if rounded >= 3
          [round_tbsp(rounded / 3.0), "tbsp"]
        else
          [rounded, "tsp"]
        end
      else # :count
        [round_count(quantity), "count"]
      end
    end
  end
end
