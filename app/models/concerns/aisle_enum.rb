module AisleEnum
  extend ActiveSupport::Concern

  included do
    enum :aisle, %i[
      produce bakery dairy_eggs meat seafood pantry
      frozen_foods beverages snacks condiments_sauces
      spices_baking household personal_care pet_supplies other
    ], prefix: true
  end
end
