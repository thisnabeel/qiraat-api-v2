class Word < ApplicationRecord
  belongs_to :line
  has_many :variations, dependent: :destroy

  # Words from the start of the line through this record (by +position+ ascending) stay on
  # +line+; every word with a greater +position+ is moved to a new line on the same page,
  # inserted immediately after the current line (existing lines at that slot and below shift down).
  #
  # @return [Line] the newly created line holding the moved words
  # @return [nil] when there are no trailing words to move
  def split_trailing_words_to_new_line!
    new_line = nil

    transaction do
      word = self.class.lock.find(id)
      current_line = Line.unscoped.lock.find(word.line_id)
      page_id = current_line.page_id
      page_record = Page.lock.find(page_id)

      line_positions = Line.unscoped.where(page_id: page_id).pluck(:position)
      if line_positions.length != line_positions.uniq.length
        page_record.normalize_line_positions!
        current_line.reload
      end

      trailing_scope = Word.where(line_id: current_line.id).where("position > ?", word.position).order(:position)
      if trailing_scope.exists?
        now = Time.current
        insert_at = current_line.position + 1

        Line.unscoped.where(page_id: page_id).where("position >= ?", insert_at).update_all("position = position + 1")
        new_line = Line.unscoped.create!(page_id: page_id, position: insert_at)

        trailing_scope.each_with_index do |w, idx|
          w.update_columns(line_id: new_line.id, position: idx + 1, updated_at: now)
        end
      end
    end

    reload if persisted?
    new_line
  end
end
