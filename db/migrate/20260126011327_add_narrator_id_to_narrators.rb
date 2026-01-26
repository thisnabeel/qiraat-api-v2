class AddNarratorIdToNarrators < ActiveRecord::Migration[8.0]
  def change
    add_reference :narrators, :narrator, null: true, foreign_key: { to_table: :narrators }
  end
end
