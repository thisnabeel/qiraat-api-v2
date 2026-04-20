class Surah < ApplicationRecord
  has_many :recitations, foreign_key: :surah_position, primary_key: :position, inverse_of: :surah

  validates :position, presence: true, uniqueness: true, inclusion: { in: 1..114 }
  validates :name_ar, presence: true
end
