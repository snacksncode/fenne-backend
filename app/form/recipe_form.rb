class RecipeForm
  include ActiveModel::Model

  attr_accessor :id, :name, :meal_types, :ingredients, :family, :liked, :time_in_minutes, :notes

  def touched_any_products?
    @touched_any_products == true
  end

  def name_collision?
    @name_collision == true
  end

  def missing_conversions
    Array(@missing_conversions).uniq
  end

  def save
    return false if invalid?

    ActiveRecord::Base.transaction do
      recipe = find_or_initialize_recipe
      recipe.name = name if name.present?
      recipe.meal_types = meal_types if meal_types.present?
      recipe.liked = liked unless liked.nil?
      recipe.time_in_minutes = time_in_minutes if time_in_minutes.present?
      recipe.notes = notes if notes.present?
      recipe.save!
      self.id = recipe.id

      if ingredients.present?
        recipe.ingredients.destroy_all
        ingredients.each_with_index do |ingredient_attributes, ingredient_index|
          attrs = ingredient_attributes.to_h.deep_symbolize_keys
          product = find_or_create_product!(attrs)
          unless ProductQuantity.ingredient_unit_compatible?(product, attrs.fetch(:unit))
            @missing_conversions ||= []
            @missing_conversions << {
              ingredient_index: ingredient_index,
              product_id: attrs.dig(:product, :id)&.to_s,
              product_name: product.name,
              ingredient_unit: attrs.fetch(:unit).to_s,
              product_unit: product.unit.to_s
            }
            errors.add(:missing_conversions, "missing")
            next
          end

          recipe.ingredients.create!(
            product: product,
            name_override: attrs[:name_override].presence,
            quantity: attrs.fetch(:quantity),
            unit: attrs.fetch(:unit)
          )
        end
        raise ActiveRecord::Rollback if missing_conversions.any?
      end

      true
    end
    return false if errors.any?

    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    false
  end

  private

  def find_or_initialize_recipe
    if id.present?
      family.recipes.find(id)
    else
      family.recipes.new
    end
  end

  def find_or_create_product!(attrs)
    product_attrs = attrs.fetch(:product).to_h.deep_symbolize_keys
    if product_attrs[:id].present?
      return family.products.find(product_attrs[:id])
    end

    form = ProductForm.new(product_attrs.merge(family: family))
    unless form.call
      errors.merge!(form.errors)
      @name_collision = true if form.name_collision?
      raise ActiveRecord::Rollback
    end
    @touched_any_products = true
    form.target
  end
end
