class Variation < ApplicationRecord
  belongs_to :narrator
  belongs_to :word
  
  validates :content, presence: true
  validates :narrator_id, uniqueness: { scope: :word_id, message: "can only have one variation per word" }
end
