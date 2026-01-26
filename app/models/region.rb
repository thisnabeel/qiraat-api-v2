class Region < ApplicationRecord
  has_many :narrators, dependent: :nullify
end
