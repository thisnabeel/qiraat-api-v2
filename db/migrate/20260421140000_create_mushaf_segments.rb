# frozen_string_literal: true

class CreateMushafSegments < ActiveRecord::Migration[8.0]
  def change
    create_table :mushaf_segments do |t|
      t.references :mushaf, null: false, foreign_key: true
      t.string :category, null: false
      t.integer :category_position, null: false
      t.string :title, null: false
      # Printed mushaf page range after applying import offset (see MushafSegment.import_from_segments_json!).
      t.integer :start_page, null: false
      t.integer :end_page, null: false
      t.timestamps
    end

    add_index :mushaf_segments,
              %i[mushaf_id category category_position],
              unique: true,
              name: "index_mushaf_segments_on_mushaf_category_position"
    add_index :mushaf_segments, %i[mushaf_id category]
  end
end
