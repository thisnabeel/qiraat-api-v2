class Page < ApplicationRecord
  belongs_to :mushaf
  has_many :lines, -> { order(:position) }, dependent: :destroy

  # Unicode ARABIC LIGATURE BISMILLAH AR-RAHMAN AR-RAHEEM — stored on basmallah lines by importers.
  BASMALA_CONTENT = "\u{FDFD}".freeze

  # Pages that show a basmala: either a line with the ﷽ word (normal import) or two adjacent
  # wordless lines in row order (image / spacer layout, e.g. some 13-line mushafs).
  # Adjacency uses row number by +lines.position+ so gaps in +position+ values still pair correctly.
  # Defaults to mushaf id 2 when none passed.
  def self.basmala(mushaf: nil)
    mushaf ||= Mushaf.find_by(id: 2)
    return none unless mushaf

    sql = sanitize_sql_array([
      <<~SQL.squish,
        SELECT p.id FROM pages p
        WHERE p.mushaf_id = ?
          AND (
            EXISTS (
              SELECT 1 FROM words w
              INNER JOIN lines l ON l.id = w.line_id
              WHERE l.page_id = p.id AND w.content = ?
            )
            OR EXISTS (
              SELECT 1
              FROM (
                SELECT lines.id AS line_id,
                       ROW_NUMBER() OVER (ORDER BY lines.position) AS rn
                FROM lines
                WHERE lines.page_id = p.id
              ) lo1
              INNER JOIN (
                SELECT lines.id AS line_id,
                       ROW_NUMBER() OVER (ORDER BY lines.position) AS rn
                FROM lines
                WHERE lines.page_id = p.id
              ) lo2 ON lo2.rn = lo1.rn + 1
              WHERE NOT EXISTS (SELECT 1 FROM words w WHERE w.line_id = lo1.line_id)
                AND NOT EXISTS (SELECT 1 FROM words w WHERE w.line_id = lo2.line_id)
            )
          )
      SQL
      mushaf.id,
      BASMALA_CONTENT
    ])

    where(mushaf_id: mushaf.id).where("pages.id IN (#{sql})")
  end

  # Interactive terminal helper:
  # - Shows selectable "gaps" before/after each line
  # - Use Up/Down arrows (or j/k), Enter to confirm, q/Esc to cancel
  # - Inserts two empty lines at the chosen gap
  def insert_surah_header
    require "io/console"

    ordered_lines = lines.order(:position).includes(:words).to_a
    raise "Page has no lines." if ordered_lines.empty?

    slots = build_surah_header_slots(ordered_lines)
    selected_index = 0

    begin
      loop do
        render_surah_header_picker(slots, selected_index)
        key = STDIN.getch

        # Arrow keys arrive as escape sequences: \e [ A / \e [ B
        if key == "\e"
          next1 = STDIN.read_nonblock(1, exception: false)
          next2 = STDIN.read_nonblock(1, exception: false)
          sequence = [key, next1, next2].join

          case sequence
          when "\e[A" # up
            selected_index = (selected_index - 1) % slots.length
          when "\e[B" # down
            selected_index = (selected_index + 1) % slots.length
          else
            puts "\nCancelled."
            return nil
          end
          next
        end

        case key
        when "\r", "\n"
          break
        when "k"
          selected_index = (selected_index - 1) % slots.length
        when "j"
          selected_index = (selected_index + 1) % slots.length
        when "q"
          puts "\nCancelled."
          return nil
        end
      end
    ensure
      puts
    end

    target_position = slots[selected_index][:insert_at_position]

    transaction do
      normalize_line_positions!
      lines.where("position >= ?", target_position).update_all("position = position + 2")
      2.times { |offset| lines.create!(position: target_position + offset) }
    end

    puts "Inserted 2 empty lines at page #{position}, starting at position #{target_position}."
    target_position
  end

  # API / app: insert basmala + surah banner rows (mushaf 2, max 13 lines per page).
  # +insert_at_position+ is the first row index for the new block (same convention as +insert_surah_header+).
  # With room for two new lines: row at +insert_at_position+ gets +surah_header_position+ -1 (basmala),
  # next row gets +surah_number+. With room for one: only the surah banner row is created.
  def insert_surah_header_block!(insert_at_position:, surah_number:)
    raise ArgumentError, "mushaf 2 only" unless mushaf_id == 2
    unless surah_number.is_a?(Integer) && surah_number.between?(1, 114)
      raise ArgumentError, "surah_number must be between 1 and 114"
    end

    insert_at = insert_at_position.to_i

    transaction do
      normalize_line_positions!
      n = lines.count
      raise ArgumentError, "page has no lines" if n.zero?

      max_lines = 13
      room = max_lines - n
      raise ArgumentError, "no room on page (max #{max_lines} lines)" if room < 1
      unless insert_at >= 1 && insert_at <= n + 1
        raise ArgumentError, "insert_at_position out of range"
      end

      shift = room >= 2 ? 2 : 1
      raise ArgumentError, "not enough room for this insert" if shift > room

      lines.where("position >= ?", insert_at).update_all("position = position + #{shift}")

      if shift == 2
        lines.create!(position: insert_at, surah_header_position: -1)
        lines.create!(position: insert_at + 1, surah_header_position: surah_number)
      else
        lines.create!(position: insert_at, surah_header_position: surah_number)
      end
    end

    self
  end

  private

  def normalize_line_positions!
    ordered = lines.order(:position).to_a
    ordered.each_with_index do |line, idx|
      expected = idx + 1
      line.update_columns(position: expected) if line.position != expected
    end
  end

  def build_surah_header_slots(ordered_lines)
    slots = []

    # Gap before first line
    slots << {
      label: "Before line 1",
      insert_at_position: 1
    }

    ordered_lines.each_with_index do |line, idx|
      words_text = line.words.order(:position).map(&:content).join(" ")
      preview = words_text.presence || "(empty line)"
      slots << {
        label: "After line #{idx + 1}: #{preview}",
        insert_at_position: idx + 2
      }
    end

    slots
  end

  def render_surah_header_picker(slots, selected_index)
    print "\e[2J\e[H" # clear screen + move cursor home
    puts "Select where to insert 2 empty surah-header lines"
    puts "Use ↑/↓ (or j/k), Enter to confirm, q/Esc to cancel"
    puts "-" * 70

    slots.each_with_index do |slot, idx|
      marker = idx == selected_index ? "➤" : " "
      puts "#{marker} #{slot[:label]}"
    end
  end
end
