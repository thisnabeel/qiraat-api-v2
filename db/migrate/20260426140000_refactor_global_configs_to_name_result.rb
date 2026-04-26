# frozen_string_literal: true

class RefactorGlobalConfigsToNameResult < ActiveRecord::Migration[8.0]
  class LegacyGlobalConfig < ApplicationRecord
    self.table_name = "global_configs"
  end

  def up
    add_column :global_configs, :name, :string
    add_column :global_configs, :result, :string

    if column_exists?(:global_configs, :min_ios_version)
      execute <<~SQL.squish
        UPDATE global_configs
        SET name = 'min_ios_version',
            result = COALESCE(min_ios_version, '0.0.1')
      SQL
      remove_column :global_configs, :min_ios_version
    end

    if column_exists?(:global_configs, :extras)
      LegacyGlobalConfig.reset_column_information
      LegacyGlobalConfig.find_each do |row|
        extras = row.read_attribute(:extras)
        next unless extras.is_a?(Hash)

        extras.each do |key, value|
          key_str = key.to_s
          next if key_str.blank?
          next if LegacyGlobalConfig.exists?(name: key_str)

          LegacyGlobalConfig.create!(
            name: key_str,
            result: value.to_s,
            created_at: Time.current,
            updated_at: Time.current
          )
        end
      end
      remove_column :global_configs, :extras
    end

    execute "DELETE FROM global_configs WHERE name IS NULL OR name = '' OR result IS NULL OR result = ''"

    execute <<~SQL.squish
      DELETE FROM global_configs gc1
      WHERE EXISTS (
        SELECT 1 FROM global_configs gc2
        WHERE gc2.name = gc1.name AND gc2.id < gc1.id
      )
    SQL

    change_column_null :global_configs, :name, false
    change_column_null :global_configs, :result, false
    add_index :global_configs, :name, unique: true

    LegacyGlobalConfig.reset_column_information
    unless LegacyGlobalConfig.exists?(name: "min_ios_version")
      LegacyGlobalConfig.create!(
        name: "min_ios_version",
        result: "0.0.1",
        created_at: Time.current,
        updated_at: Time.current
      )
    end
  end

  def down
    remove_index :global_configs, :name, if_exists: true

    min_val = LegacyGlobalConfig.find_by(name: "min_ios_version")&.read_attribute(:result) || "0.0.1"
    LegacyGlobalConfig.delete_all

    remove_column :global_configs, :name
    remove_column :global_configs, :result

    add_column :global_configs, :min_ios_version, :string, null: false, default: "0.0.1"
    add_column :global_configs, :extras, :jsonb, null: false, default: {}

    LegacyGlobalConfig.reset_column_information
    LegacyGlobalConfig.create!(
      min_ios_version: min_val,
      extras: {},
      created_at: Time.current,
      updated_at: Time.current
    )
  end
end
