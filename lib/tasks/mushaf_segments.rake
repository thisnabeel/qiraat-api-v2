# frozen_string_literal: true

namespace :mushaf_segments do
  desc "Re-import juz+surah for mushaf 2 from ../react-native/segments.json (Django mushaf id 1). MUSHAF_SEGMENT_PAGE_OFFSET=N. MUSHAF_SEGMENT_CATEGORIES=juz,surah"
  task import: :environment do
    offset = ENV.fetch("MUSHAF_SEGMENT_PAGE_OFFSET", "0").to_i
    raw = ENV.fetch("MUSHAF_SEGMENT_CATEGORIES", "juz,surah")
    cats = raw.split(",").map(&:strip).compact_blank
    cats = %w[juz surah] if cats.empty?
    result = MushafSegment.import_from_segments_json!(
      target_mushaf_id: 2,
      source_fixture_mushaf_id: 1,
      page_offset: offset,
      categories: cats
    )
    puts result.inspect
  end

  desc "Re-import only juz (same options as import)."
  task import_juz: :environment do
    offset = ENV.fetch("MUSHAF_SEGMENT_PAGE_OFFSET", "0").to_i
    puts MushafSegment.import_from_segments_json!(
      target_mushaf_id: 2,
      source_fixture_mushaf_id: 1,
      page_offset: offset,
      categories: %w[juz]
    ).inspect
  end
end
