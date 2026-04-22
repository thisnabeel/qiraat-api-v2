# frozen_string_literal: true

# Boundaries for Go-to-Page style UI (juz / surah) for a mushaf.
# Rows are populated from the app’s legacy `react-native/segments.json` export (Django `mushaf` id),
# with an optional integer page offset rasterized into +start_page+ / +end_page+.
class MushafSegment < ApplicationRecord
  belongs_to :mushaf

  validates :category, presence: true, inclusion: { in: %w[juz surah] }
  validates :category_position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :title, presence: true
  validates :start_page, :end_page, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validate :end_page_gte_start_page

  # Imports from `react-native/segments.json` (fixture `mushaf` id) into +target_mushaf_id+.
  # +page_offset+ is added to JSON first_page / last_page once and stored (rasterized).
  def self.import_from_segments_json!(target_mushaf_id:, source_fixture_mushaf_id:, page_offset: 0, categories: %w[juz surah])
    mushaf = Mushaf.find_by(id: target_mushaf_id)
    return { imported: 0, skipped: true, reason: "mushaf #{target_mushaf_id} missing" } unless mushaf

    path = Rails.root.join("..", "react-native", "segments.json")
    unless File.file?(path)
      return { imported: 0, skipped: true, reason: "segments.json not found at #{path}" }
    end

    list = JSON.parse(File.read(path))
    offset = page_offset.to_i
    now = Time.current
    rows = []

    list.each do |item|
      next unless item.is_a?(Hash) && item["model"].to_s.include?("mushafsegment")

      fields = item["fields"] || {}
      next unless categories.include?(fields["category"].to_s)

      next unless fields["mushaf"].to_i == source_fixture_mushaf_id.to_i

      raw_first = fields["first_page"].to_i
      raw_last = fields["last_page"].to_i
      start_page = raw_first + offset
      end_page = raw_last + offset
      start_page = 1 if start_page < 1
      end_page = start_page if end_page < start_page

      rows << {
        mushaf_id: mushaf.id,
        category: fields["category"].to_s,
        category_position: fields["category_position"].to_i,
        title: fields["title"].to_s,
        start_page: start_page,
        end_page: end_page,
        created_at: now,
        updated_at: now
      }
    end

    transaction do
      where(mushaf_id: mushaf.id, category: categories).delete_all
      insert_all!(rows) if rows.any?
    end

    { imported: rows.size, skipped: false }
  end

  private

  def end_page_gte_start_page
    return if start_page.blank? || end_page.blank?

    errors.add(:end_page, "must be >= start_page") if end_page < start_page
  end
end
