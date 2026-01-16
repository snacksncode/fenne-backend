# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

require "json"

# Seed food items from JSON file
food_items_path = Rails.root.join("db", "seeds", "food_items.json")

if File.exist?(food_items_path)
  food_items_data = JSON.parse(File.read(food_items_path))

  food_items_data.each do |item|
    FoodItem.find_or_create_by!(name: item["name"], aisle: item["category"])
  end

  puts "Seeded #{FoodItem.count} food items"
else
  puts "Warning: food_items.json not found at #{food_items_path}"
end
