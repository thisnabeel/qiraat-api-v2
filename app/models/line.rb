class Line < ApplicationRecord
  belongs_to :page
  has_many :words, -> { order(:position) }, dependent: :destroy
  
  default_scope { order(:position) }
end
