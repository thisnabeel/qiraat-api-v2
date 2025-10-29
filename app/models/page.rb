class Page < ApplicationRecord
  belongs_to :mushaf
  has_many :lines, dependent: :destroy
end
