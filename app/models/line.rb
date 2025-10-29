class Line < ApplicationRecord
  belongs_to :page
  has_many :words, dependent: :destroy
end
