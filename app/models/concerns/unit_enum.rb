module UnitEnum
  extend ActiveSupport::Concern

  included do
    enum :unit, %i[g kg ml l fl_oz cup tbsp tsp pt qt oz lb count], prefix: true
  end
end
