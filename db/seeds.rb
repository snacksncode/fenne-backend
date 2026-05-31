# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

require "json"

# Seed the global autocomplete dictionary from JSON.
product_suggestions_path = Rails.root.join("db", "seeds", "product_suggestions.json")

if File.exist?(product_suggestions_path)
  product_suggestions_data = JSON.parse(File.read(product_suggestions_path))

  product_suggestions_data.each do |item|
    ProductSuggestion.find_or_create_by!(name: item["name"], aisle: item["category"])
  end

  puts "Seeded #{ProductSuggestion.count} product suggestions"
else
  puts "Warning: product_suggestions.json not found at #{product_suggestions_path}"
end
