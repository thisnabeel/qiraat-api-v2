# frozen_string_literal: true

# Boundaries for Go-to-Page style UI (juz / surah) for a mushaf.
# Juz rows are often imported from `react-native/segments.json`.
# Surah rows for mushaf 2 are rebuilt from `lines.surah_header_position` via +rebuild_surah_from_line_headers!+
# (titles from `react-native/surah_numbers.json`).
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

  # Deletes existing +category: "surah"+ rows for the mushaf, then inserts one segment per distinct
  # surah found on lines (+surah_header_position+ > 0), in mushaf reading order (page ASC, line ASC).
  # +start_page+ is the page of the first such line for that surah; +end_page+ is derived from the
  # next surah’s +start_page+ (or +total_pages+). Titles come from +surah_numbers.json+ keys "1".."114".
  #
  # Rails console: +MushafSegment.rebuild_surah_from_line_headers!(mushaf_id: 2)+
  def self.rebuild_surah_from_line_headers!(mushaf_id:, surah_numbers_json_path: nil)
    mushaf_id = mushaf_id.to_i
    mushaf = Mushaf.find_by(id: mushaf_id)
    return { rebuilt: 0, skipped: true, reason: "mushaf #{mushaf_id} missing" } unless mushaf

    path = surah_numbers_json_path || Rails.root.join("..", "react-native", "surah_numbers.json")
    unless File.file?(path)
      return { rebuilt: 0, skipped: true, reason: "surah_numbers.json missing at #{path}" }
    end

    titles = JSON.parse(File.read(path))
    total_pages = mushaf.pages.maximum(:position).to_i
    total_pages = 1 if total_pages < 1

    first_page_by_surah = {}
    Line.unscoped
      .joins(:page)
      .where(pages: { mushaf_id: mushaf.id })
      .where("lines.surah_header_position > ?", 0)
      .order("pages.position ASC, lines.position ASC")
      .pluck("pages.position", "lines.surah_header_position")
      .each do |page_pos, surah_raw|
        n = surah_raw.to_i
        next if n < 1 || n > 114

        first_page_by_surah[n] ||= page_pos.to_i
      end

    ordered = first_page_by_surah.map { |num, start_page| { num: num, start_page: start_page } }
    ordered.sort_by! { |h| [h[:start_page], h[:num]] }

    now = Time.current
    out = []
    ordered.each_with_index do |e, i|
      start_p = e[:start_page]
      end_p =
        if i + 1 < ordered.size
          np = ordered[i + 1][:start_page]
          np > start_p ? np - 1 : start_p
        else
          total_pages
        end
      end_p = start_p if end_p < start_p

      title = titles[e[:num].to_s].to_s
      title = "سورة #{e[:num]}" if title.blank?

      out << {
        mushaf_id: mushaf.id,
        category: "surah",
        category_position: e[:num],
        title: title,
        start_page: start_p,
        end_page: end_p,
        created_at: now,
        updated_at: now
      }
    end

    transaction do
      where(mushaf_id: mushaf.id, category: "surah").delete_all
      insert_all!(out) if out.any?
    end

    { rebuilt: out.size, skipped: false, mushaf_id: mushaf.id }
  end

  private

  def end_page_gte_start_page
    return if start_page.blank? || end_page.blank?

    errors.add(:end_page, "must be >= start_page") if end_page < start_page
  end
end
