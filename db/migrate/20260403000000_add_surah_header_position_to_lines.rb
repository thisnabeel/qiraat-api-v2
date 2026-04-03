class AddSurahHeaderPositionToLines < ActiveRecord::Migration[8.0]
  def change
    add_column :lines, :surah_header_position, :integer, default: 0, null: false
  end
end
