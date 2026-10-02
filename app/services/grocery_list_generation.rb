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
    selected_ids = Array(selection[:checked_product_ids]).map(&:to_i)
    plan = product_plan(selected_ids: selected_ids)

    ApplicationRecord.transaction do
      plan.each do |product, demand|
        quantity = product.measured? ? demand[:needed] : ProductQuantity.quantity_after_pantry(product, demand[:needed])
        chosen = purchase_override(product)
        if !product.measured? && chosen != :unchanged && !chosen.nil?
          next if product.counted? && chosen.zero?
          raise ArgumentError, "Purchase quantity must be greater than 0" unless chosen > 0
          quantity = chosen
        end
        next if quantity <= 0 && !product.measured?

        GroceryItem.add_product!(
          family: family,
          product: product,
          quantity: quantity,
          source: "generated",
          recipe_ids: demand[:recipe_ids],
          purchase_override: chosen
        )
      end
    end
  end

  private

  attr_reader :family, :start_date, :end_date, :selection

  # Keep exact Recipe demand and attribution together, before Pantry subtraction
  # or Pack Size rounding. Selection happens first so unchecked Products need no
  # Conversion and cannot prevent accepted Products from being generated.
  def product_plan(selected_ids: nil)
    ingredients = scheduled_items.flat_map { |item| item.recipe.ingredients }
      .reject { |ingredient| ingredient.product.kitchen_basic? }
    ingredients.select! { |ingredient| selected_ids.include?(ingredient.product_id) } if selected_ids

    plan = ingredients.group_by(&:product).transform_values do |group|
      {
        needed: group.sum { |ingredient| ProductQuantity.ingredient_need(ingredient) },
        recipe_ids: group.map(&:recipe_id).uniq
      }
    end
    running_low_timed_products.each do |product|
      next if selected_ids && !selected_ids.include?(product.id)

      plan[product] ||= { needed: 1.to_d, recipe_ids: [] }
    end
    plan
  end

  def product_preview_rows
    plan = product_plan
    existing_items = family.grocery_items.where(product_id: plan.keys.map(&:id)).index_by(&:product_id)
    recipe_ids = plan.values.flat_map { |demand| demand[:recipe_ids] }
    recipe_ids |= existing_items.values.flat_map(&:normalized_recipe_ids)
    recipes_by_id = family.recipes.where(id: recipe_ids).index_by(&:id)

    plan.filter_map do |product, demand|
      existing = existing_items[product.id]
      next if product.timed? && existing

      preview_row(product, demand, existing, recipes_by_id)
    end
  end

  def preview_row(product, demand, existing, recipes_by_id)
    needed = demand[:needed]
    quantity = ProductQuantity.quantity_after_pantry(product, needed)
    return if quantity <= 0 && product.timed?

    purchase = if product.measured?
      PurchaseSuggestion.call(product: product, needed: needed + (existing&.needed_quantity || 0))
    elsif product.counted?
      PurchaseSuggestion.call(product: product, needed: needed)
    end
    overridden = product.measured? && existing&.purchase_fixed?
    quantity = purchase[:suggested_quantity] if purchase
    quantity = existing.quantity if overridden && purchase

    recipe_ids = demand[:recipe_ids]
    recipe_ids |= existing.normalized_recipe_ids if product.measured? && existing
    recipes = recipe_ids.filter_map do |id|
      recipe = recipes_by_id[id]
      { id: recipe.id.to_s, name: recipe.name } if recipe
    end
    {
      product_id: product.id.to_s,
      product: ProductSerializer.render(product),
      quantity: quantity.to_f,
      purchase: purchase,
      quantity_overridden: !!overridden,
      unit: product.unit,
      checked: !product.timed?,
      recipes: recipes,
      running_low: product.timed?
    }
  end

  def purchase_override(product)
    entry = Array(selection[:purchase_quantities]).find { |row| row[:product_id].to_i == product.id }
    entry ? entry[:quantity] : :unchanged
  end

  def scheduled_items
    @scheduled_items ||= begin
      schedule_day_ids = family.schedule_days.in_range(start_date, end_date).pluck(:id)
      ScheduleItem.where(schedule_day_id: schedule_day_ids)
        .kind_recipe
        .includes(recipe: { ingredients: { product: :pantry_entries } })
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
end
