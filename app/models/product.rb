class Product < ApplicationRecord
  include AisleEnum
  include UnitEnum

  belongs_to :family
  has_many :pantry_entries, dependent: :destroy
  has_many :ingredients
  has_many :grocery_items

  enum :reminder_frequency_unit, { days: 0, weeks: 1, months: 2 }, prefix: :reminder

  before_validation :normalize_name
  before_destroy :prevent_delete_if_referenced, prepend: true
  after_commit :refresh_search_index, on: [ :create, :update ]
  after_commit :remove_search_index, on: :destroy

  attr_reader :blocked_by_recipes, :blocked_by_grocery_items, :blocked_by_pantry_entries

  validates :name, :aisle, :unit, presence: true
  validates :name, uniqueness: { scope: :family_id, case_sensitive: false }
  validates :quantity, numericality: { greater_than: 0, less_than_or_equal_to: 1_000_000 }, allow_nil: true
  validates :pack_count, numericality: { only_integer: true, greater_than_or_equal_to: 2 }, allow_nil: true
  validates :reminder_frequency_value,
    numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 3650 },
    allow_nil: true
  validate :mutual_exclusivity
  validate :reminder_fields_pair
  validate :quantity_unit_compatibility

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
    quantity.present? && !unit_count?
  end

  def counted?
    !kitchen_basic? && !timed? && !measured?
  end

  private

  def normalize_name
    self.name = name.to_s.strip
  end

  def mutual_exclusivity
    modes = [ measured?, timed?, kitchen_basic? ].count(true)
    errors.add(:base, "tracking modes are mutually exclusive") if modes > 1
  end

  def reminder_fields_pair
    value_present = reminder_frequency_value.present?
    unit_present = reminder_frequency_unit.present?
    return if value_present == unit_present

    errors.add(:base, "reminder frequency value and unit must be set together")
  end

  def quantity_unit_compatibility
    return unless quantity.present? && unit_count?

    errors.add(:quantity, "cannot be used with count unit")
  end

  def prevent_delete_if_referenced
    recipes = ingredients.includes(:recipe).map(&:recipe).uniq
    grocery_rows = grocery_items.to_a
    pantry_rows = pantry_entries.to_a
    return if recipes.empty? && grocery_rows.empty? && pantry_rows.empty?

    @blocked_by_recipes = recipes
    @blocked_by_grocery_items = grocery_rows
    @blocked_by_pantry_entries = pantry_rows
    errors.add(:base, "product is referenced; swap or remove first")
    throw :abort
  end

  def refresh_search_index
    ProductSearchIndex.upsert_product(self)
  end

  def remove_search_index
    ProductSearchIndex.delete("product", id)
  end
end
