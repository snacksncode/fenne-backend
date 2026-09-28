# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_09_28_120000) do
  create_table "consumption_logs", force: :cascade do |t|
    t.integer "family_id", null: false
    t.integer "meal_type", null: false
    t.date "schedule_date", null: false
    t.json "deductions", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "recipe_name", null: false
    t.index ["family_id", "schedule_date", "meal_type"], name: "idx_consumption_one_per_slot", unique: true
    t.index ["family_id"], name: "index_consumption_logs_on_family_id"
  end

  create_table "families", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "timezone"
  end

  create_table "family_invitations", force: :cascade do |t|
    t.integer "family_id", null: false
    t.integer "from_user_id", null: false
    t.integer "to_user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_family_invitations_on_family_id"
    t.index ["from_user_id"], name: "index_family_invitations_on_from_user_id"
    t.index ["to_user_id"], name: "index_family_invitations_on_to_user_id"
  end

  create_table "food_items", force: :cascade do |t|
    t.string "name", null: false
    t.integer "aisle", null: false
    t.integer "family_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_food_items_on_family_id"
  end

  create_table "grocery_items", force: :cascade do |t|
    t.integer "family_id", null: false
    t.string "name", null: false
    t.decimal "quantity", null: false
    t.integer "aisle", null: false
    t.integer "unit", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 0, null: false
    t.integer "product_id"
    t.integer "source", default: 1, null: false
    t.json "recipe_ids", default: [], null: false
    t.decimal "needed_quantity", precision: 15, scale: 6
    t.boolean "quantity_overridden", default: true, null: false
    t.index ["family_id", "product_id"], name: "idx_grocery_items_one_active_product", unique: true, where: "product_id IS NOT NULL AND status IN (0, 1)"
    t.index ["family_id", "status"], name: "index_grocery_items_on_family_id_and_status"
    t.index ["family_id"], name: "index_grocery_items_on_family_id"
    t.index ["product_id"], name: "index_grocery_items_on_product_id"
  end

  create_table "ingredients", force: :cascade do |t|
    t.integer "recipe_id", null: false
    t.integer "unit", null: false
    t.decimal "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "product_id", null: false
    t.string "name_override"
    t.index ["product_id"], name: "index_ingredients_on_product_id"
    t.index ["recipe_id"], name: "index_ingredients_on_recipe_id"
  end

  create_table "pantry_entries", force: :cascade do |t|
    t.integer "family_id", null: false
    t.integer "product_id", null: false
    t.decimal "quantity_remaining", precision: 10, scale: 3, default: "0.0", null: false
    t.datetime "last_acquired", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id", "product_id"], name: "index_pantry_entries_on_family_id_and_product_id", unique: true
    t.index ["family_id"], name: "index_pantry_entries_on_family_id"
    t.index ["product_id"], name: "index_pantry_entries_on_product_id"
  end

  create_table "product_suggestions", force: :cascade do |t|
    t.string "name", null: false
    t.integer "aisle", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "LOWER(TRIM(name))", name: "idx_product_suggestions_name_ci", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.integer "family_id", null: false
    t.string "name", null: false
    t.integer "aisle", null: false
    t.decimal "quantity", precision: 10, scale: 3
    t.integer "unit", default: 12, null: false
    t.integer "pack_count"
    t.integer "reminder_frequency_value"
    t.integer "reminder_frequency_unit"
    t.boolean "is_kitchen_basic", default: false, null: false
    t.json "conversions", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "pack_sizes", default: [], null: false
    t.index "family_id, LOWER(TRIM(name))", name: "idx_products_family_name_ci", unique: true
    t.index ["family_id"], name: "index_products_on_family_id"
  end

  create_table "recipes", force: :cascade do |t|
    t.integer "family_id", null: false
    t.string "name", null: false
    t.integer "meal_types_bitmask", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "liked", default: false, null: false
    t.integer "time_in_minutes", default: 0, null: false
    t.string "notes", default: "", null: false
    t.index ["family_id"], name: "index_recipes_on_family_id"
  end

  create_table "schedule_days", force: :cascade do |t|
    t.integer "family_id", null: false
    t.date "date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id", "date"], name: "index_schedule_days_on_family_id_and_date", unique: true
    t.index ["family_id"], name: "index_schedule_days_on_family_id"
  end

  create_table "schedule_items", force: :cascade do |t|
    t.integer "schedule_day_id", null: false
    t.integer "kind", null: false
    t.integer "meal_type", null: false
    t.integer "recipe_id"
    t.string "dining_out_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id"], name: "index_schedule_items_on_recipe_id"
    t.index ["schedule_day_id", "meal_type"], name: "index_schedule_items_on_schedule_day_id_and_meal_type", unique: true
    t.index ["schedule_day_id"], name: "index_schedule_items_on_schedule_day_id"
  end

  create_table "session_tokens", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "token"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_session_tokens_on_user_id"
  end

  create_table "todos", force: :cascade do |t|
    t.string "content"
    t.boolean "is_completed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_todos_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "family_id", null: false
    t.index ["family_id"], name: "index_users_on_family_id"
  end

  add_foreign_key "consumption_logs", "families"
  add_foreign_key "family_invitations", "families"
  add_foreign_key "family_invitations", "users", column: "from_user_id"
  add_foreign_key "family_invitations", "users", column: "to_user_id"
  add_foreign_key "food_items", "families"
  add_foreign_key "grocery_items", "families"
  add_foreign_key "grocery_items", "products"
  add_foreign_key "ingredients", "products"
  add_foreign_key "ingredients", "recipes"
  add_foreign_key "pantry_entries", "families"
  add_foreign_key "pantry_entries", "products"
  add_foreign_key "products", "families"
  add_foreign_key "recipes", "families"
  add_foreign_key "schedule_days", "families"
  add_foreign_key "schedule_items", "recipes"
  add_foreign_key "schedule_items", "schedule_days"
  add_foreign_key "session_tokens", "users"
  add_foreign_key "todos", "users"
  add_foreign_key "users", "families"
end
