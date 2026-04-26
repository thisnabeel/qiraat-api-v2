# frozen_string_literal: true

# Key/value rows for app-wide settings (e.g. name: "min_ios_version", result: "1.0.60").
# Clients read the map via GET /api/global_config.
class GlobalConfig < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :result, presence: true

  def self.value_for(name)
    find_by(name: name.to_s)&.result
  end

  def self.set!(name, value)
    rec = find_or_initialize_by(name: name.to_s)
    rec.result = value.to_s
    rec.save!
    rec
  end

  def self.as_client_json
    pluck(:name, :result).to_h
  end
end
