class Page < ApplicationRecord
  belongs_to :mushaf
  has_many :lines, -> { order(:position) }, dependent: :destroy
end
