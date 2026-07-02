class GroceryListGeneration
  def initialize(family:, start_date:, end_date:, selection: {})
    @family = family
    @start_date = start_date
    @end_date = end_date
    @selection = selection.to_h.symbolize_keys
  end

  def preview
    {
      products: product_preview_rows,
      recipes: PreviewRecipeSerializer.render_many(scheduled_items.group_by(&:recipe))
    }
  end

  def generate!
    product_needs, selected_ingredients = selected_product_needs

    ApplicationRecord.transaction do
      product_needs.each do |product, needed|
        quantity = ProductQuantity.quantity_after_pantry(product, needed)
        next if quantity <= 0

        recipe_ids = selected_ingredients.select { |ingredient| ingredient.product_id == product.id }.map(&:recipe_id).uniq
        GroceryListEntryAdder.call(
          family: family,
          product: product,
          quantity: quantity,
          source: "generated",
          recipe_ids: recipe_ids
        )
      end
    end
  end

  private

  attr_reader :family, :start_date, :end_date, :selection

  def selected_product_needs
    all = scheduled_ingredients.reject { |ingredient| ingredient.product.kitchen_basic? }

    checked_product_ids = Array(selection[:checked_product_ids]).map(&:to_i)
    selected_ingredients = all.select { |ingredient| checked_product_ids.include?(ingredient.product_id) }
    needs = group_needs_by_product(selected_ingredients)
    running_low_timed_products.each do |product|
      needs[product] ||= 1.to_d if checked_product_ids.include?(product.id)
    end

    [ needs, selected_ingredients ]
  end

  def product_preview_rows
    ingredients = scheduled_ingredients
      .reject { |ingredient| ingredient.product.kitchen_basic? }

    needs = group_needs_by_product(ingredients)
    running_low_timed_products.each { |product| needs[product] ||= 1.to_d }

    needs.filter_map do |product, needed|
      quantity = ProductQuantity.quantity_after_pantry(product, needed)
      next if quantity <= 0
      next if product.shape == :timed && active_grocery_item_exists?(product)

      recipe_ids = ingredients.select { |ingredient| ingredient.product_id == product.id }.map(&:recipe_id).uniq
      recipes = family.recipes.where(id: recipe_ids).map { |recipe| { id: recipe.id.to_s, name: recipe.name } }
      {
        product_id: product.id.to_s,
        product: ProductSerializer.render(product),
        quantity: quantity.to_f,
        unit: product.unit,
        checked: product.shape != :timed,
        recipes: recipes,
        running_low: product.shape == :timed
      }
    end
  end

  def scheduled_ingredients
    scheduled_items.flat_map { |item| item.recipe.ingredients }
  end

  def scheduled_items
    @scheduled_items ||= begin
      schedule_day_ids = family.schedule_days.in_range(start_date, end_date).pluck(:id)
      ScheduleItem.where(schedule_day_id: schedule_day_ids)
        .kind_recipe
        .includes(recipe: { ingredients: :product })
    end
  end

  def group_needs_by_product(ingredients)
    ingredients.group_by(&:product).transform_values do |group|
      group.sum { |ingredient| ProductQuantity.ingredient_need(ingredient) }
    end
  end

  def running_low_timed_products
    @running_low_timed_products ||= family.products
      .where(is_kitchen_basic: false)
      .where.not(reminder_frequency_value: nil)
      .where.not(reminder_frequency_unit: nil)
      .includes(:pantry_entries)
      .select { |product| ProductQuantity.running_low?(product) }
  end

  def active_grocery_item_exists?(product)
    family.grocery_items.where(product: product).where(status: [ :pending, :completed ]).exists?
  end
end
