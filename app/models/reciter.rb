class Reciter < ApplicationRecord
  has_many :recitations, dependent: :destroy

  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true
end
