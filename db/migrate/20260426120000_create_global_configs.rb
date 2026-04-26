# frozen_string_literal: true

class CreateGlobalConfigs < ActiveRecord::Migration[8.0]
  def up
    create_table :global_configs do |t|
      t.string :min_ios_version, null: false, default: "0.0.1"
      t.timestamps
    end

    execute <<~SQL.squish
      INSERT INTO global_configs (min_ios_version, created_at, updated_at)
      VALUES ('0.0.1', NOW(), NOW())
    SQL
  end

  def down
    drop_table :global_configs
  end
end
