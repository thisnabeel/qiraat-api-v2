# frozen_string_literal: true

# Traverses mushaf id 2 (13-line IndoPak) in reading order, tracks surah/ayah like
# Mushaf#backfill_ayahs_from_markers!, and records one row per surah (from surah 3):
# first verse only, with start/end page and line (1-based line index on that page).
# End row is emitted when verse 1 ends (۟ U+06DF or PUA circle). +end_has_pua_circle+
# is true when the end word uses a PUA ayah-circle (U+F500..U+F61D).
#
# Usage (from api/):
#   bin/rails mushaf2:collect_ayah_circle_pua
#   OUT=../path/to/out.json bin/rails mushaf2:collect_ayah_circle_pua
#
namespace :mushaf2 do
  desc "First verse per surah (≥3): start/end page+line; end_has_pua_circle if marker uses PUA (mushaf 2)"
  task collect_ayah_circle_pua: :environment do
    mushaf = Mushaf.find_by(id: 2)
    abort "Mushaf id 2 not found." unless mushaf

    pua_start = 0xF500
    pua_end = 0xF61D
    counts = Mushaf::SURAH_AYAH_COUNTS

    ayah_circle_pua = lambda do |content|
      return false if content.blank?

      content.each_codepoint.any? { |cp| cp >= pua_start && cp <= pua_end }
    end

    verse_end_marker = lambda do |content|
      return false if content.blank?

      content.include?("\u06df") || ayah_circle_pua.call(content)
    end

    ordered_lines = Line
      .unscoped
      .joins(:page)
      .where(pages: { mushaf_id: mushaf.id })
      .includes(:page, :words)
      .order("pages.position ASC, lines.position ASC")
      .to_a

    collected = []
    current_surah = 1
    current_verse = 1
    capture_v1_start = false
    v1_start_page = nil
    v1_start_line = nil

    ordered_lines.each do |line|
      words = line.words.sort_by(&:position)
      next if words.empty?

      page_pos = line.page.position
      line_pos = line.position

      words.each do |word|
        if capture_v1_start
          v1_start_page = page_pos
          v1_start_line = line_pos
          capture_v1_start = false
        end

        if verse_end_marker.call(word.content)
          if current_surah >= 3 && current_verse == 1
            sp = v1_start_page || page_pos
            sl = v1_start_line || line_pos
            collected << {
              surah: current_surah,
              verse: 1,
              start_page: sp,
              start_line: sl,
              end_page: page_pos,
              end_line: line_pos,
              end_has_pua_circle: ayah_circle_pua.call(word.content)
            }
          end

          if current_verse >= counts[current_surah - 1]
            if current_surah < counts.length
              current_surah += 1
              current_verse = 1
              capture_v1_start = true if current_surah >= 3
            end
          else
            current_verse += 1
          end
        end
      end
    end

    out = ENV["OUT"].presence || Rails.root.join("../react-native/mushaf2_ayah_circle_pua_from_surah3.json").to_s
    File.write(out, JSON.pretty_generate(collected) << "\n")

    puts "Wrote #{collected.size} entries to #{out}"
  end
end
