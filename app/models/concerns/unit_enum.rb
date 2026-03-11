module UnitEnum
  extend ActiveSupport::Concern

  included do
    enum :unit, { g: 0, kg: 1, ml: 2, l: 3, fl_oz: 4, cup: 5, tbsp: 6, tsp: 7, qt: 9, oz: 10, lb: 11, count: 12 }, prefix: true
  end
end
