namespace :import do
  desc "Import mushaf layout from SQLite database and DOCX files (indopak-13-lines folder)"
  task mushaf_from_sqlite: :environment do
    require 'sqlite3'
    require 'pathname'
    require 'zip'
    require 'nokogiri'

    DB_FILE = Rails.root.join('indopak-13-lines', 'indopak-13-lines-taj-company.db')
    PAGES_DIR = Rails.root.join('indopak-13-lines', 'pages')
    MUSHAF_TITLE = "Indopak 13 lines layout(Taj company)"

    unless File.exist?(DB_FILE)
      puts "Error: Database file not found at #{DB_FILE}"
      exit 1
    end

    unless Dir.exist?(PAGES_DIR)
      puts "Error: Pages directory not found at #{PAGES_DIR}"
      exit 1
    end

    def extract_text_from_docx(docx_path)
      # Extract text from DOCX file
      # DOCX files are ZIP archives containing XML
      text_content = []
      
      Zip::File.open(docx_path) do |zip_file|
        doc_xml = zip_file.read('word/document.xml')
        doc = Nokogiri::XML(doc_xml)
        
        # Extract all text nodes using the correct namespace
        doc.xpath('//w:t', 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main').each do |text_node|
          text = text_node.text
          text_content << text if text && !text.strip.empty?
        end
        
        # If no text found, try without namespace as fallback
        if text_content.empty?
          doc.xpath('//t').each do |text_node|
            text = text_node.text
            text_content << text if text && !text.strip.empty?
          end
        end
      end
      
      # Join all text with spaces, but preserve single spaces
      result = text_content.join(' ').squeeze(' ').strip
      result.empty? ? nil : result
    rescue => e
      Rails.logger.error "Error extracting text from #{docx_path}: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      nil
    end

    def extract_words_from_docx_text(text, first_word_id, last_word_id)
      # Split text into words (by spaces or Arabic text boundaries)
      # This is a simple approach - may need refinement based on actual DOCX structure
      words = text.split(/\s+/).reject(&:empty?)
      
      # Return words in the specified range
      word_count = last_word_id - first_word_id + 1
      words[0, word_count]
    end

    puts "=" * 80
    puts "Importing mushaf layout from SQLite database and DOCX files"
    puts "Database file: #{DB_FILE}"
    puts "Pages directory: #{PAGES_DIR}"
    puts "Mushaf Title: #{MUSHAF_TITLE}"
    puts "=" * 80
    puts

    db = SQLite3::Database.open(DB_FILE)
    db.results_as_hash = true

    # Get info from database
    info = db.execute("SELECT * FROM info LIMIT 1").first
    if info
      puts "Database Info:"
      puts "  Name: #{info['name']}"
      puts "  Pages: #{info['number_of_pages']}"
      puts "  Lines per page: #{info['lines_per_page']}"
      puts "  Font: #{info['font_name']}"
      puts
    end

    # Find or create the mushaf
    mushaf = Mushaf.find_or_create_by!(title: MUSHAF_TITLE)
    puts "Mushaf ID: #{mushaf.id}"
    puts

    start_time = Time.now
    total_pages = db.execute("SELECT COUNT(DISTINCT page_number) FROM pages").first[0]
    processed_pages = 0
    processed_lines = 0

    puts "Processing #{total_pages} pages..."
    puts "-" * 80

    # Process pages in batches
    (1..total_pages).each do |page_number|
      ActiveRecord::Base.transaction do
        # Find or create page
        page = mushaf.pages.find_or_initialize_by(position: page_number)
        
        if page.new_record?
          page.save!
        else
          # Fast delete existing lines and their children to avoid duplicates
          line_ids = page.lines.pluck(:id)
          if line_ids.any?
            Variation.where(word_id: Word.where(line_id: line_ids).select(:id)).delete_all
            Word.where(line_id: line_ids).delete_all
            Line.where(id: line_ids).delete_all
          end
        end

        # Get all lines for this page
        page_rows = db.execute(
          "SELECT * FROM pages WHERE page_number = ? ORDER BY line_number",
          page_number
        )

        # Calculate the starting word_id for this page
        # Word IDs are global across all pages, so we need to find the minimum word_id on this page
        page_min_word_id = db.execute(
          "SELECT MIN(first_word_id) FROM pages WHERE page_number = ? AND first_word_id IS NOT NULL",
          page_number
        ).first[0]
        
        # If no word_id found on this page, skip word extraction
        page_starting_word_id = page_min_word_id || 1

        # Load DOCX file for this page if it exists
        docx_path = PAGES_DIR.join("#{page_number}.docx")
        docx_text = nil
        
        if File.exist?(docx_path)
          docx_text = extract_text_from_docx(docx_path)
          if docx_text.nil?
            Rails.logger.warn "Could not extract text from DOCX for page #{page_number}"
          end
        else
          Rails.logger.warn "DOCX file not found for page #{page_number}: #{docx_path}"
        end

        # Build a map of word IDs to content from DOCX if available
        word_id_to_content = {}
        if docx_text && page_starting_word_id
          # Extract all words from DOCX and map them by their global word IDs
          # Word IDs are global, so we start from the page's starting word_id
          # Split by spaces, but be careful with Arabic text
          all_words = docx_text.split(/\s+/).reject { |w| w.strip.empty? }
          current_word_id = page_starting_word_id
          
          all_words.each do |word|
            word = word.strip
            next if word.empty?
            word_id_to_content[current_word_id] = word
            current_word_id += 1
          end
          
          # Debug logging for first few pages
          if page_number <= 3
            Rails.logger.debug "Page #{page_number}: Extracted #{all_words.length} words, mapped from word_id #{page_starting_word_id} to #{current_word_id - 1}"
            Rails.logger.debug "Sample words: #{all_words.first(5).join(', ')}"
          end
        elsif !docx_text
          Rails.logger.warn "No DOCX text extracted for page #{page_number}"
        end

        page_rows.each do |row|
          line = page.lines.build(
            position: row['line_number']
          )
          line.save!

          line_type = row['line_type']
          first_word_id = row['first_word_id']
          last_word_id = row['last_word_id']

          # For ayah lines, extract words from DOCX or use placeholder
          if line_type == 'ayah' && first_word_id && last_word_id
            word_position = 1
            
            (first_word_id..last_word_id).each do |word_id|
              # Get word content from DOCX if available, otherwise use placeholder
              word_content = word_id_to_content[word_id]
              
              if word_content.nil?
                Rails.logger.warn "Word ID #{word_id} not found in DOCX for page #{page_number}, line #{row['line_number']}"
                word_content = "[word_id_#{word_id}]"
              end
              
              line.words.create!(
                position: word_position,
                content: word_content,
                ayah: nil
              )
              word_position += 1
            end
          elsif line_type == 'basmallah'
            line.words.create!(
              position: 1,
              content: '﷽',
              ayah: nil
            )
          end
          # For surah_name lines, we don't create words

          processed_lines += 1
        end

        # Reload page to ensure all associations are loaded
        page.reload
        
        # Log completion of each page
        # Count words through lines association (Page -> Lines -> Words)
        line_ids = page.lines.pluck(:id)
        page_word_count = line_ids.any? ? Word.where(line_id: line_ids).count : 0
        page_line_count = page.lines.count
        
        processed_pages += 1
        
        puts "✓ Completed page #{page_number}/#{total_pages} (#{page_line_count} lines, #{page_word_count} words)"
        
        # Also log every 50 pages summary
        if processed_pages % 50 == 0
          puts "- Progress: #{processed_pages}/#{total_pages} pages (#{processed_lines} lines total)..."
        end
      end
    end

    db.close

    end_time = Time.now
    duration = end_time - start_time

    puts "-" * 80
    puts "Import completed!"
    puts "  Total pages: #{processed_pages}"
    puts "  Total lines: #{processed_lines}"
    puts "  Duration: #{(duration / 60).round(2)} minutes"
    puts "  Completed at: #{end_time}"
    puts "=" * 80
  end
end

