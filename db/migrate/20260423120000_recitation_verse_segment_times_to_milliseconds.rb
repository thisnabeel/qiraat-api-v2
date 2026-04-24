# Store segment boundaries as integer milliseconds for sub-second accuracy.
# API still exposes start_time / end_time as float seconds (see RecitationVerseSegment#as_api_json).
#
# Safety:
# - Widen to bigint BEFORE multiplying so existing second counts never pass through a 32-bit
#   integer multiply (avoids overflow on pathological large timestamps).
# - Whole `up` runs in one transaction so a failure does not leave mixed units.
# - `down` divides back to seconds while still bigint, then narrows columns.
#
# Runs once from schema_migrations; do not edit after production deploy (add a new migration instead).
class RecitationVerseSegmentTimesToMilliseconds < ActiveRecord::Migration[8.0]
  def up
    transaction do
      # Values are still whole seconds; widen first so the next step cannot overflow integer.
      change_column :recitation_verse_segments, :start_time, :bigint, null: false
      change_column :recitation_verse_segments, :end_time, :bigint, null: false

      execute <<~SQL.squish
        UPDATE recitation_verse_segments
        SET start_time = start_time * 1000,
            end_time = end_time * 1000
      SQL
    end
  end

  def down
    transaction do
      # Milliseconds → whole seconds (truncate); safe while columns are still bigint.
      execute <<~SQL.squish
        UPDATE recitation_verse_segments
        SET start_time = start_time / 1000,
            end_time = end_time / 1000
      SQL

      change_column :recitation_verse_segments, :start_time, :integer, null: false
      change_column :recitation_verse_segments, :end_time, :integer, null: false
    end
  end
end
