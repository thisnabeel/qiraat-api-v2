class Recitation < ApplicationRecord
  belongs_to :reciter
  belongs_to :recitation_narrator
  belongs_to :surah, foreign_key: :surah_position, primary_key: :position, optional: true

  has_many :recitation_verse_segments, dependent: :destroy

  validates :surah_position, presence: true, inclusion: { in: 1..114 }
  validates :audio_url, presence: true
  validates :surah_position, uniqueness: { scope: [:reciter_id, :recitation_narrator_id] }

  def surah_number
    surah_position
  end

  def riwayah_name
    recitation_narrator&.slug.to_s
  end

  def reciter_name
    reciter&.slug.to_s
  end

  def generate_segments!
    result = NovitaSegmenter.call(self)
    segments = result["segments"]

    unless segments.is_a?(Array)
      raise "NovitaSegmenter error: response missing segments array"
    end

    now = Time.current
    payload = segments.map do |raw|
      verse = raw["verse"].to_s
      next if verse.blank?

      {
        recitation_id: id,
        verse: verse,
        start_time: RecitationVerseSegment.ms_from_api_seconds(raw["start_time"]),
        end_time: RecitationVerseSegment.ms_from_api_seconds(raw["end_time"]),
        created_at: now,
        updated_at: now
      }
    end.compact

    RecitationVerseSegment.transaction do
      recitation_verse_segments.delete_all
      RecitationVerseSegment.insert_all!(payload) if payload.any?
    end

    result
  end
end
