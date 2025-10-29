class Narrator < ApplicationRecord
  has_many :variations, dependent: :destroy
end
