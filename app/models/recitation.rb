class Recitation < ApplicationRecord
  belongs_to :reciter
  belongs_to :recitation_narrator
  belongs_to :surah, foreign_key: :surah_position, primary_key: :position, optional: true

  has_many :recitation_verse_segments, dependent: :destroy

  validates :surah_position, presence: true, inclusion: { in: 1..114 }
  validates :audio_url, presence: true
  validates :surah_position, uniqueness: { scope: [:reciter_id, :recitation_narrator_id] }
end
