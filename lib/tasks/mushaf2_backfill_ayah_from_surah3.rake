# frozen_string_literal: true

# Sets words.ayah to "surah:verse" for mushaf id 2 from the first word of surah 3 verse 1
# through the end of the mushaf (reading order: page → line → word). Earlier words are
# not changed. Verse boundaries: ۟ (U+06DF) or PUA ayah-circle (U+F500..U+F73C).
#
# From api/:
#   bin/rails mushaf2:backfill_ayah_from_surah3              # dry-run (default)
#   DRY_RUN=0 bin/rails mushaf2:backfill_ayah_from_surah3   # apply
#   FROM_SURAH=5 DRY_RUN=0 bin/rails mushaf2:backfill_ayah_from_surah3
#
namespace :mushaf2 do
  desc "Backfill words.ayah from surah 3 onward for mushaf id 2 (DRY_RUN=0 to write)"
  task backfill_ayah_from_surah3: :environment do
    mushaf = Mushaf.find_by(id: 2)
    abort "Mushaf id 2 not found." unless mushaf

    from = ENV["FROM_SURAH"].presence&.to_i || 3
    dry = ENV["DRY_RUN"] != "0"

    result = mushaf.backfill_ayahs_from_surah_forward!(from_surah: from, dry_run: dry)
    puts JSON.pretty_generate(result)
  end
end
