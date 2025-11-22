class RecipeForm
  include ActiveModel::Model

  attr_accessor :id, :name, :meal_types, :ingredients, :family

  validates :name, :meal_types, :family, :ingredients, presence: true
  validate :validate_ingredients

  def save
    return false if invalid?

    ActiveRecord::Base.transaction do
      recipe = find_or_initialize_recipe
      recipe.name = name
      recipe.meal_types = meal_types
      recipe.save!
      self.id = recipe.id

      recipe.ingredients.destroy_all
      ingredients.map do |ingredient_attributes|
        recipe.ingredients.create!(ingredient_attributes)
      end

      true
    end
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

  def validate_ingredients
    unless ingredients.is_a?(Array)
      return errors.add(:ingredients, "must be an array")
    end

    has_invalid_ingredient = ingredients.any? do |ingredient_attributes|
      ingredient = Ingredient.new(ingredient_attributes)
      ingredient.recipe = Recipe.new
      return !ingredient.valid?
    end

    if has_invalid_ingredient
      errors.add(:ingredients, "contains invalid data")
    end
  end
end
