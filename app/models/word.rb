class Word < ApplicationRecord
  belongs_to :line
  has_many :variations, dependent: :destroy
end
