class RecitationVerseSegment < ApplicationRecord
  belongs_to :recitation

  validates :verse, presence: true
  validates :start_time, :end_time, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Milliseconds from the start of the track (DB columns `start_time` / `end_time`).
  # JSON API uses float seconds via {#as_api_json} and accepts float seconds on update.

  # Hash with id, verse, start_time, end_time as float seconds for API clients.
  def as_api_json
    {
      id: id,
      verse: verse,
      start_time: start_time / 1000.0,
      end_time: end_time / 1000.0
    }
  end

  # Converts client/API seconds (float) to stored milliseconds (integer).
  def self.ms_from_api_seconds(seconds)
    (seconds.to_f * 1000).round
  end

  # "107:3" -> 3 (for progress counts)
  def ayah_number
    verse.to_s.split(":").last.to_i
  end
end
