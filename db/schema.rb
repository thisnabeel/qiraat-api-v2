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

ActiveRecord::Schema[8.0].define(version: 2026_01_26_011654) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "lines", force: :cascade do |t|
    t.integer "position"
    t.bigint "page_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["page_id"], name: "index_lines_on_page_id"
  end

  create_table "mushafs", force: :cascade do |t|
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "narrators", force: :cascade do |t|
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "narrator_id"
    t.bigint "region_id"
    t.string "highlight_color"
    t.index ["narrator_id"], name: "index_narrators_on_narrator_id"
    t.index ["region_id"], name: "index_narrators_on_region_id"
  end

  create_table "pages", force: :cascade do |t|
    t.integer "position"
    t.bigint "mushaf_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mushaf_id"], name: "index_pages_on_mushaf_id"
  end

  create_table "regions", force: :cascade do |t|
    t.text "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "variations", force: :cascade do |t|
    t.string "content"
    t.bigint "narrator_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "word_id", null: false
    t.index ["narrator_id"], name: "index_variations_on_narrator_id"
    t.index ["word_id"], name: "index_variations_on_word_id"
  end

  create_table "words", force: :cascade do |t|
    t.integer "position"
    t.string "content"
    t.bigint "line_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ayah"
    t.index ["line_id"], name: "index_words_on_line_id"
  end

  add_foreign_key "lines", "pages"
  add_foreign_key "narrators", "narrators"
  add_foreign_key "narrators", "regions"
  add_foreign_key "pages", "mushafs"
  add_foreign_key "variations", "narrators"
  add_foreign_key "variations", "words"
  add_foreign_key "words", "lines"
end
