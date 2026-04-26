# frozen_string_literal: true

class AddExtrasToGlobalConfigs < ActiveRecord::Migration[8.0]
  def change
    add_column :global_configs, :extras, :jsonb, null: false, default: {}
  end
end
