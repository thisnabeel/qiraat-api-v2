class Mushaf < ApplicationRecord
  has_many :pages, dependent: :destroy
end
