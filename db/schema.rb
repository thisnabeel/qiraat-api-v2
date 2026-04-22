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

ActiveRecord::Schema[8.0].define(version: 2026_04_21_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "lines", force: :cascade do |t|
    t.integer "position"
    t.bigint "page_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "surah_header_position", default: 0, null: false
    t.index ["page_id"], name: "index_lines_on_page_id"
  end

  create_table "mushaf_segments", force: :cascade do |t|
    t.bigint "mushaf_id", null: false
    t.string "category", null: false
    t.integer "category_position", null: false
    t.string "title", null: false
    t.integer "start_page", null: false
    t.integer "end_page", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mushaf_id", "category", "category_position"], name: "index_mushaf_segments_on_mushaf_category_position", unique: true
    t.index ["mushaf_id", "category"], name: "index_mushaf_segments_on_mushaf_id_and_category"
    t.index ["mushaf_id"], name: "index_mushaf_segments_on_mushaf_id"
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
    t.bigint "content_revision", default: 0, null: false
    t.index ["mushaf_id"], name: "index_pages_on_mushaf_id"
  end

  create_table "recitation_narrators", force: :cascade do |t|
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_recitation_narrators_on_slug", unique: true
  end

  create_table "recitation_verse_segments", force: :cascade do |t|
    t.bigint "recitation_id", null: false
    t.string "verse", null: false
    t.integer "start_time", null: false
    t.integer "end_time", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recitation_id", "verse"], name: "index_rvs_on_recitation_and_verse"
    t.index ["recitation_id"], name: "index_recitation_verse_segments_on_recitation_id"
  end

  create_table "recitations", force: :cascade do |t|
    t.bigint "reciter_id", null: false
    t.bigint "recitation_narrator_id", null: false
    t.integer "surah_position", null: false
    t.string "audio_url", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recitation_narrator_id"], name: "index_recitations_on_recitation_narrator_id"
    t.index ["reciter_id", "recitation_narrator_id", "surah_position"], name: "index_recitations_on_reciter_narrator_surah", unique: true
    t.index ["reciter_id"], name: "index_recitations_on_reciter_id"
  end

  create_table "reciters", force: :cascade do |t|
    t.string "slug", null: false
    t.string "name", null: false
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_reciters_on_slug", unique: true
  end

  create_table "regions", force: :cascade do |t|
    t.text "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "surahs", force: :cascade do |t|
    t.integer "position", null: false
    t.string "name_ar", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_surahs_on_position", unique: true
  end

  create_table "variations", force: :cascade do |t|
    t.string "content"
    t.bigint "narrator_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "word_id", null: false
    t.jsonb "special_characters"
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
  add_foreign_key "mushaf_segments", "mushafs"
  add_foreign_key "narrators", "narrators"
  add_foreign_key "narrators", "regions"
  add_foreign_key "pages", "mushafs"
  add_foreign_key "recitation_verse_segments", "recitations"
  add_foreign_key "recitations", "recitation_narrators"
  add_foreign_key "recitations", "reciters"
  add_foreign_key "variations", "narrators"
  add_foreign_key "variations", "words"
  add_foreign_key "words", "lines"
end
