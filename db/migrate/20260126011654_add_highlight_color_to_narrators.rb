class AddHighlightColorToNarrators < ActiveRecord::Migration[8.0]
  def change
    add_column :narrators, :highlight_color, :string, default: "#f9ca24"
  end
end
