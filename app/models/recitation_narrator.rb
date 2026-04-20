class RecitationNarrator < ApplicationRecord
  has_many :recitations, dependent: :destroy

  validates :slug, presence: true, uniqueness: true
  validates :title, presence: true
end
