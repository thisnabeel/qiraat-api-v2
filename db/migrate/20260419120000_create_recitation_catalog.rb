class CreateRecitationCatalog < ActiveRecord::Migration[8.0]
  def change
    create_table :recitation_narrators do |t|
      t.string :slug, null: false
      t.string :title, null: false
      t.timestamps
    end
    add_index :recitation_narrators, :slug, unique: true

    create_table :reciters do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.string :avatar_url
      t.timestamps
    end
    add_index :reciters, :slug, unique: true

    create_table :surahs do |t|
      t.integer :position, null: false
      t.string :name_ar, null: false
      t.timestamps
    end
    add_index :surahs, :position, unique: true

    create_table :recitations do |t|
      t.references :reciter, null: false, foreign_key: true
      t.references :recitation_narrator, null: false, foreign_key: true
      t.integer :surah_position, null: false
      t.string :audio_url, null: false
      t.timestamps
    end
    add_index :recitations, [:reciter_id, :recitation_narrator_id, :surah_position], unique: true, name: "index_recitations_on_reciter_narrator_surah"
  end
end
