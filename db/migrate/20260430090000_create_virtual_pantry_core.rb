class CreateVirtualPantryCore < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.references :family, foreign_key: true, null: false
      t.string :name, null: false
      t.integer :aisle, null: false
      t.decimal :quantity, precision: 10, scale: 3
      t.integer :unit, null: false, default: 12
      t.integer :pack_count
      t.integer :reminder_frequency_value
      t.integer :reminder_frequency_unit
      t.boolean :is_kitchen_basic, default: false, null: false
      t.json :conversions, default: {}, null: false
      t.timestamps
    end

    add_index :products,
      "family_id, LOWER(TRIM(name))",
      unique: true,
      name: "idx_products_family_name_ci"

    create_table :product_suggestions do |t|
      t.string :name, null: false
      t.integer :aisle, null: false
      t.timestamps
    end

    add_index :product_suggestions,
      "LOWER(TRIM(name))",
      unique: true,
      name: "idx_product_suggestions_name_ci"

    add_reference :ingredients, :product, foreign_key: true
    add_column :ingredients, :name_override, :string

    add_column :families, :timezone, :string

    create_table :pantry_entries do |t|
      t.references :family, foreign_key: true, null: false
      t.references :product, foreign_key: true, null: false
      t.decimal :quantity_remaining, precision: 10, scale: 3, default: 0, null: false
      t.datetime :last_acquired, null: false
      t.timestamps
    end

    add_index :pantry_entries, [:family_id, :product_id], unique: true

    create_table :consumption_logs do |t|
      t.references :family, foreign_key: true, null: false
      t.references :recipe, foreign_key: true
      t.integer :meal_type, null: false
      t.date :schedule_date, null: false
      t.json :deductions, default: [], null: false
      t.timestamps
    end

    add_index :consumption_logs,
      [:family_id, :schedule_date, :meal_type],
      unique: true,
      name: "idx_consumption_one_per_slot"

    add_reference :grocery_items, :product, foreign_key: true
    add_column :grocery_items, :source, :integer, default: 1, null: false
    add_column :grocery_items, :recipe_ids, :json, default: [], null: false
    add_index :grocery_items, [:family_id, :status]
  end
end
