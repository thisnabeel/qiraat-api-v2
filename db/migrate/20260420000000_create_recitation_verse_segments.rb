class CreateRecitationVerseSegments < ActiveRecord::Migration[8.0]
  def change
    create_table :recitation_verse_segments do |t|
      t.references :recitation, null: false, foreign_key: true
      t.string :verse, null: false
      t.integer :start_time, null: false
      t.integer :end_time, null: false
      t.timestamps
    end
    add_index :recitation_verse_segments, [:recitation_id, :verse], name: "index_rvs_on_recitation_and_verse"
  end
end
