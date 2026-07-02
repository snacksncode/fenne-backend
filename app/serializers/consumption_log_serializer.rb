class ConsumptionLogSerializer
  def self.render(log)
    {
      id: log.id.to_s,
      recipe_name: log.recipe_name,
      recipe: { name: log.recipe_name },
      meal_type: log.meal_type,
      schedule_date: log.schedule_date.iso8601,
      deductions: deductions_with_names(log)
    }
  end

  def self.render_many(logs)
    logs.map { |log| render(log) }
  end

  def self.deductions_with_names(log)
    product_ids = log.deductions.map { |deduction| deduction["product_id"] }.compact
    products_by_id = log.family.products.where(id: product_ids).index_by { |product| product.id.to_s }

    log.deductions.map do |deduction|
      product_id = deduction["product_id"].to_s
      deduction.merge("product_name" => deduction["product_name"] || products_by_id[product_id]&.name)
    end
  end
end
