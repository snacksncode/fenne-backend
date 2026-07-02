module Conversion
  DIMENSIONS = {
    mass_metric: {"g" => 1.0, "kg" => 1000.0},
    mass_imperial: {"oz" => 1.0, "lb" => 16.0},
    volume_metric: {"ml" => 1.0, "l" => 1000.0},
    spoon: {"tsp" => 1.0, "tbsp" => 3.0},
    volume_imperial: {"fl_oz" => 1.0, "cup" => 8.0, "qt" => 32.0},
    count: {"count" => 1.0}
  }.freeze

  def self.dimension_of(unit)
    DIMENSIONS.each do |dimension, units|
      return dimension if units.key?(unit.to_s)
    end
    nil
  end

  def self.same_dimension?(unit_a, unit_b)
    dimension = dimension_of(unit_a)
    dimension.present? && dimension == dimension_of(unit_b)
  end

  def self.factor(from_unit, to_unit)
    dimension = dimension_of(from_unit)
    return nil unless dimension && dimension == dimension_of(to_unit)

    DIMENSIONS[dimension][from_unit.to_s] / DIMENSIONS[dimension][to_unit.to_s]
  end
end
