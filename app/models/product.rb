class Product < ApplicationRecord
  include AisleEnum
  include UnitEnum

  belongs_to :family
  has_many :pantry_entries, dependent: :destroy
  has_many :ingredients
  has_many :recipes, -> { distinct }, through: :ingredients
  has_many :grocery_items, dependent: :destroy

  enum :reminder_frequency_unit, { days: 0, weeks: 1, months: 2 }, prefix: :reminder

  before_validation :normalize_name
  before_destroy :prevent_delete_if_referenced, prepend: true
  after_commit :refresh_search_index, on: [ :create, :update ]
  after_commit :remove_search_index, on: :destroy

  attr_reader :blocked_by_recipes

  validates :name, :aisle, :unit, presence: true
  validates :name, uniqueness: { scope: :family_id, case_sensitive: false }
  validates :reminder_frequency_value,
    numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 3650 },
    allow_nil: true
  validate :mutual_exclusivity
  validate :reminder_fields_pair

  def shape
    return :kitchen_basic if kitchen_basic?
    return :timed if timed?
    return :measured if measured?
    :counted
  end

  def kitchen_basic?
    is_kitchen_basic
  end

  def timed?
    reminder_frequency_value.present? && reminder_frequency_unit.present?
  end

  def measured?
    !unit_count? && !timed? && !kitchen_basic?
  end

  def counted?
    unit_count? && !timed? && !kitchen_basic?
  end

  private

  def normalize_name
    self.name = name.to_s.strip
  end

  def mutual_exclusivity
    return unless timed? && kitchen_basic?

    errors.add(:base, "tracking modes are mutually exclusive")
  end

  def reminder_fields_pair
    value_present = reminder_frequency_value.present?
    unit_present = reminder_frequency_unit.present?
    return if value_present == unit_present

    errors.add(:base, "reminder frequency value and unit must be set together")
  end

  def prevent_delete_if_referenced
    recipes = self.recipes.includes(ingredients: :product).to_a
    return if recipes.empty?

    @blocked_by_recipes = recipes
    errors.add(:base, "product is used in recipes; remove it from those recipes first")
    throw :abort
  end

  def refresh_search_index
    ProductSearchIndex.upsert_product(self)
  end

  def remove_search_index
    ProductSearchIndex.delete("product", id)
  end
end
