class RecipeForm
  include ActiveModel::Model

  attr_accessor :id, :name, :meal_types, :ingredients, :family, :liked, :time_in_minutes, :notes

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
        ingredients.each do |ingredient_attributes|
          recipe.ingredients.create!(ingredient_attributes)
        end
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
end
