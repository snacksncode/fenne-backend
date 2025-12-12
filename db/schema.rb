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

ActiveRecord::Schema[8.0].define(version: 2025_12_12_123405) do
  create_table "families", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  create_table "grocery_items", force: :cascade do |t|
    t.integer "family_id", null: false
    t.string "name", null: false
    t.decimal "quantity", null: false
    t.integer "aisle", null: false
    t.integer "unit", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 0, null: false
    t.index ["family_id"], name: "index_grocery_items_on_family_id"
  end

  create_table "ingredients", force: :cascade do |t|
    t.integer "recipe_id", null: false
    t.string "name", null: false
    t.integer "unit", null: false
    t.decimal "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "aisle", default: 14, null: false
    t.index ["recipe_id"], name: "index_ingredients_on_recipe_id"
  end

  create_table "recipes", force: :cascade do |t|
    t.integer "family_id", null: false
    t.string "name", null: false
    t.integer "meal_types_bitmask", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "liked", default: false, null: false
    t.integer "time_in_minutes", default: 0, null: false
    t.index ["family_id"], name: "index_recipes_on_family_id"
  end

  create_table "schedule_days", force: :cascade do |t|
    t.integer "family_id", null: false
    t.date "date", null: false
    t.integer "breakfast_recipe_id"
    t.integer "lunch_recipe_id"
    t.integer "dinner_recipe_id"
    t.boolean "is_shopping_day", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["breakfast_recipe_id"], name: "index_schedule_days_on_breakfast_recipe_id"
    t.index ["dinner_recipe_id"], name: "index_schedule_days_on_dinner_recipe_id"
    t.index ["family_id", "date"], name: "index_schedule_days_on_family_id_and_date", unique: true
    t.index ["family_id"], name: "index_schedule_days_on_family_id"
    t.index ["lunch_recipe_id"], name: "index_schedule_days_on_lunch_recipe_id"
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

  add_foreign_key "family_invitations", "families"
  add_foreign_key "family_invitations", "users", column: "from_user_id"
  add_foreign_key "family_invitations", "users", column: "to_user_id"
  add_foreign_key "grocery_items", "families"
  add_foreign_key "ingredients", "recipes"
  add_foreign_key "recipes", "families"
  add_foreign_key "schedule_days", "families"
  add_foreign_key "schedule_days", "recipes", column: "breakfast_recipe_id"
  add_foreign_key "schedule_days", "recipes", column: "dinner_recipe_id"
  add_foreign_key "schedule_days", "recipes", column: "lunch_recipe_id"
  add_foreign_key "session_tokens", "users"
  add_foreign_key "todos", "users"
  add_foreign_key "users", "families"
end
