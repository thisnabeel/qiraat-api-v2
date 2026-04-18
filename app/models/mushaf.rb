class Mushaf < ApplicationRecord
  has_many :pages, dependent: :destroy
  has_many :lines, through: :pages
  has_many :words, through: :lines
  SURAH_AYAH_COUNTS = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 110, 98,
    135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
    54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11,
    18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17,
    19, 26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5,
    6
  ].freeze

  # Backfills words.ayah for this mushaf by traversing in canonical reading order:
  # pages.position ASC -> lines.position ASC -> words.position ASC.
  #
  # Surah boundaries are inferred from layout start-lines:
  # - first non-empty line
  # - non-empty lines preceded by >= 2 empty lines (or >= 1 for the 9th boundary)
  #
  # Verse boundaries are inferred by ayah-circle marker words.
  def backfill_ayahs_from_markers!(dry_run: true)
    ordered_lines = ordered_lines_with_words
    return backfill_summary([], [], dry_run: dry_run) if ordered_lines.empty?

    updates = []
    marker_word_ids = []

    current_surah = 1
    current_verse = 1

    ordered_lines.each do |line|
      words = line.words.sort_by(&:position)
      next if words.empty?

      words.each do |word|
        ayah_label = "#{current_surah}:#{current_verse}"
        updates << [word.id, ayah_label]

        next unless ayah_marker_word?(word.content)

        marker_word_ids << word.id
        if current_verse >= SURAH_AYAH_COUNTS[current_surah - 1]
          next if current_surah >= SURAH_AYAH_COUNTS.length

          current_surah += 1
          current_verse = 1
        else
          current_verse += 1
        end
      end
    end

    apply_ayah_updates!(updates) unless dry_run
    backfill_summary(updates, marker_word_ids, dry_run: dry_run)
  end

  # Like +backfill_ayahs_from_markers!+ but only sets +words.ayah+ from the first word of
  # +from_surah+ verse 1 through the end of the mushaf. Earlier words are left unchanged.
  #
  # Reading order: +ordered_lines_with_words+. Verse boundaries match mushaf id 2 tooling
  # (۟ U+06DF or PUA ayah-circle U+F500..U+F61D); other mushafs use +ayah_marker_word?+ only.
  def backfill_ayahs_from_surah_forward!(from_surah: 3, dry_run: true)
    ordered_lines = ordered_lines_with_words
    return backfill_summary([], [], dry_run: dry_run) if ordered_lines.empty?

    updates = []
    marker_word_ids = []
    current_surah = 1
    current_verse = 1
    started = false

    ordered_lines.each do |line|
      words = line.words.sort_by(&:position)
      next if words.empty?

      words.each do |word|
        started = true if !started && current_surah == from_surah && current_verse == 1

        if started
          ayah_label = "#{current_surah}:#{current_verse}"
          updates << [word.id, ayah_label]
        end

        next unless verse_boundary_word?(word.content)

        marker_word_ids << word.id
        if current_verse >= SURAH_AYAH_COUNTS[current_surah - 1]
          next if current_surah >= SURAH_AYAH_COUNTS.length

          current_surah += 1
          current_verse = 1
        else
          current_verse += 1
        end
      end
    end

    apply_ayah_updates!(updates) unless dry_run
    backfill_summary(updates, marker_word_ids, dry_run: dry_run)
  end

  # Validates spacing before lines that contain first-ayah words (x:1):
  # - surah 9 expects >= 1 preceding empty line
  # - all other surahs expect >= 2 preceding empty lines
  def validate_surah_start_spacing
    ordered_lines = ordered_lines_with_words
    line_index = {}
    ordered_lines.each_with_index { |line, idx| line_index[line.id] = idx }

    target_lines = ordered_lines.filter_map.with_index do |line, idx|
      ayah_on_line = line.words.map(&:ayah).compact.find { |ayah| ayah.end_with?(":1") }
      next nil unless ayah_on_line

      previous_non_empty_line = previous_non_empty_line_for(ordered_lines, idx)
      previous_ayahs = previous_non_empty_line ? previous_non_empty_line.words.map(&:ayah).compact.uniq : []
      next nil if previous_ayahs.include?(ayah_on_line)

      [line, ayah_on_line]
    end

    failures = target_lines.filter_map do |line, first_ayah|
      surah = first_ayah.split(":").first.to_i
      expected_empty_lines = surah == 9 ? 1 : 2
      empty_before = contiguous_empty_lines_before(ordered_lines, line_index.fetch(line.id))
      next nil if empty_before >= expected_empty_lines

      {
        surah: surah,
        ayah: first_ayah,
        page_position: line.page.position,
        line_position: line.position,
        empty_lines_before: empty_before,
        expected_minimum: expected_empty_lines
      }
    end

    {
      total_target_lines: target_lines.size,
      failures: failures,
      passed: failures.empty?
    }
  end

  private

  def ordered_lines_with_words
    # Line has default_scope order(:position), which would sort all line-1s across pages
    # before line-2s. Reading order must be page-major: page position, then line position.
    Line
      .unscoped
      .joins(:page)
      .where(pages: { mushaf_id: id })
      .includes(:page, :words)
      .order("pages.position ASC, lines.position ASC")
      .to_a
  end

  def contiguous_empty_lines_before(ordered_lines, current_index)
    count = 0
    idx = current_index - 1

    while idx >= 0 && ordered_lines[idx].words.empty?
      count += 1
      idx -= 1
    end

    count
  end

  def previous_non_empty_line_for(ordered_lines, current_index)
    idx = current_index - 1
    while idx >= 0
      line = ordered_lines[idx]
      return line if line.words.any?

      idx -= 1
    end
    nil
  end

  def ayah_marker_word?(content)
    return false if content.blank?

    # In this dataset, ayah-end circles consistently include U+06DF (۟).
    # Some words also include private-use glyphs, but ۟ is the most stable marker.
    content.include?("۟")
  end

  # Verse-end detection for +backfill_ayahs_from_surah_forward!+: mushaf 2 IndoPak uses
  # ۟ and/or PUA circle codepoints in marker words; other mushafs keep ۟-only.
  def verse_boundary_word?(content)
    return ayah_marker_word?(content) if id != 2

    return false if content.blank?

    content.include?("\u06df") || ayah_circle_pua_codepoints?(content)
  end

  def ayah_circle_pua_codepoints?(content)
    content.each_codepoint.any? { |cp| cp >= 0xF500 && cp <= 0xF61D }
  end

  def apply_ayah_updates!(updates)
    updates.each_slice(1_000) do |chunk|
      ids = chunk.map(&:first)
      case_sql = chunk.map { |word_id, ayah| "WHEN #{word_id} THEN #{ActiveRecord::Base.connection.quote(ayah)}" }.join(" ")

      Word.where(id: ids).update_all("ayah = CASE id #{case_sql} END")
    end
  end

  def backfill_summary(updates, marker_word_ids, dry_run:)
    distinct_first_verses = updates.map(&:last).uniq.count { |ayah| ayah.end_with?(":1") }

    {
      dry_run: dry_run,
      total_word_updates: updates.size,
      marker_words_detected: marker_word_ids.size,
      distinct_first_verses: distinct_first_verses
    }
  end
end
