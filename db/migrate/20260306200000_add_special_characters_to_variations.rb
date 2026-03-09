class AddSpecialCharactersToVariations < ActiveRecord::Migration[8.0]
  def change
    add_column :variations, :special_characters, :jsonb, default: nil
  end
end
