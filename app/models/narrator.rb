class Narrator < ApplicationRecord
  belongs_to :narrator, optional: true, class_name: 'Narrator'
  belongs_to :region, optional: true
  
  has_many :narrators, class_name: 'Narrator', foreign_key: 'narrator_id', dependent: :destroy
  
  has_many :variations, dependent: :destroy
end
