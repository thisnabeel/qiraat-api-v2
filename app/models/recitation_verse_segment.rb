class RecitationVerseSegment < ApplicationRecord
  belongs_to :recitation

  validates :verse, presence: true
  validates :start_time, :end_time, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # "107:3" -> 3 (for progress counts)
  def ayah_number
    verse.to_s.split(":").last.to_i
  end
end
