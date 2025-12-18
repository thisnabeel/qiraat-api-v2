namespace :scrape do
  desc "Scrape mushaf layout pages from qul.tarteel.ai (847 pages, 100 pages per batch with 10 min delay)"
  task mushaf_layout: :environment do
    require 'nokogiri'
    require 'open-uri'
    require 'json'
    require 'net/http'
    require 'openssl'

    BASE_URL = 'https://qul.tarteel.ai/resources/mushaf-layout/313?page='
    TOTAL_PAGES = 847
    PAGES_PER_BATCH = 100
    DELAY_BETWEEN_BATCHES = 600 # 10 minutes in seconds
    MUSHAF_TITLE = "Indopak 13 lines layout(Taj company)"

    def fetch_page(page_number)
      url = "#{BASE_URL}#{page_number}"
      uri = URI(url)
      
      Rails.logger.debug "Fetching: #{url}"
      
      # Use Net::HTTP directly to have more control over the request
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      request['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      request['Accept-Language'] = 'en-US,en;q=0.9'
      request['Cache-Control'] = 'no-cache'
      request['Pragma'] = 'no-cache'
      request['Referer'] = "#{BASE_URL}#{page_number - 1}" if page_number > 1
      
      response = http.request(request)
      
      if response.code != '200'
        raise "HTTP Error: #{response.code} for page #{page_number}"
      end
      
      content = response.body
      Rails.logger.debug "Fetched #{content.length} bytes from page #{page_number}"
      
      # Verify we got the right page by checking the title/metadata
      if !content.include?("Page #{page_number}") && !content.include?("page #{page_number}")
        Rails.logger.warn "Warning: Page #{page_number} verification failed - title might not match"
        Rails.logger.warn "Content snippet: #{content[0..200]}"
      end
      
      content
    rescue OpenURI::HTTPError => e
      Rails.logger.error "HTTP Error fetching page #{page_number}: #{e.message}"
      raise "HTTP Error: #{e.message} for page #{page_number}"
    rescue => e
      Rails.logger.error "Error fetching page #{page_number}: #{e.message}"
      raise
    end

    def convert_js_to_json(js_string)
      # Convert JavaScript object notation to JSON
      # Step 1: Add quotes around unquoted object keys
      result = js_string.gsub(/([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:/, '\1"\2":')
      
      # Step 2: Replace single quotes with double quotes (but handle escaped quotes)
      # This is a simple approach - for more complex cases we'd need to parse properly
      result = result.gsub(/'/, '"')
      
      result
    rescue => e
      Rails.logger.error "Error converting JS to JSON: #{e.message}"
      js_string # Return original if conversion fails
    end

    def extract_balanced_braces(content, start_pos, open_char, close_char)
      # Extract balanced brackets/braces starting from a position
      depth = 0
      start_idx = nil
      
      (start_pos...content.length).each do |i|
        char = content[i]
        if char == open_char
          depth += 1
          start_idx = i if depth == 1
        elsif char == close_char
          depth -= 1
          if depth == 0 && start_idx
            return content[start_idx..i]
          end
        end
      end
      nil
    end

    def extract_javascript_data(html_content)
      doc = Nokogiri::HTML(html_content)
      
      # Try to find pageData and wordData declarations in HTML first
      page_data_start = html_content.index('const pageData =')
      word_data_start = html_content.index('const wordData =')
      search_content = html_content
      
      # If not found in HTML, search in script tags
      if !page_data_start || !word_data_start
        scripts = doc.css('script')
        scripts.each do |script|
          content = script.text
          pd_start = content.index('const pageData =')
          wd_start = content.index('const wordData =')
          
          if pd_start && wd_start
            page_data_start = pd_start
            word_data_start = wd_start
            search_content = content
            break
          end
        end
      end
      
      if !page_data_start || !word_data_start
        Rails.logger.error "Could not find pageData or wordData in HTML"
        Rails.logger.error "Page data start: #{page_data_start ? 'found' : 'not found'}"
        Rails.logger.error "Word data start: #{word_data_start ? 'found' : 'not found'}"
        return nil
      end
      
      # Find the array start for pageData
      page_data_array_start = search_content.index('[', page_data_start)
      word_data_object_start = search_content.index('{', word_data_start)
      
      if !page_data_array_start || !word_data_object_start
        Rails.logger.error "Could not find array/object start markers"
        return nil
      end
      
      # Extract balanced brackets/braces
      page_data_js = extract_balanced_braces(search_content, page_data_array_start, '[', ']')
      word_data_js = extract_balanced_braces(search_content, word_data_object_start, '{', '}')
      
      if !page_data_js || !word_data_js
        Rails.logger.error "Could not extract balanced brackets/braces"
        Rails.logger.error "Page data extracted: #{page_data_js ? 'yes' : 'no'}"
        Rails.logger.error "Word data extracted: #{word_data_js ? 'yes' : 'no'}"
        return nil
      end
      
      begin
        # Convert JavaScript to JSON
        page_data_json = convert_js_to_json(page_data_js)
        word_data_json = convert_js_to_json(word_data_js)
        
        page_data = JSON.parse(page_data_json)
        word_data = JSON.parse(word_data_json)
        
        # Extract ayah mapping from HTML
        ayah_mapping = extract_ayah_mapping(html_content)
        
        return { page_data: page_data, word_data: word_data, ayah_mapping: ayah_mapping }
      rescue JSON::ParserError => e
        Rails.logger.error "Error parsing JSON: #{e.message}"
        Rails.logger.error "Page data snippet: #{page_data_js[0..500]}"
        Rails.logger.error "Word data snippet: #{word_data_js[0..500]}"
        return nil
      end
    end

    def extract_ayah_mapping(html_content)
      # Extract ayah information from data-ayah attributes
      doc = Nokogiri::HTML(html_content)
      ayah_mapping = {}
      
      # Find all elements with data-ayah attribute
      doc.css('[data-ayah]').each do |element|
        ayah_value = element['data-ayah']
        word_text = element.text.strip
        
        # Store mapping of word text to ayah (surah:ayah format)
        if ayah_value && word_text && !word_text.empty?
          # Multiple words might share the same ayah
          ayah_mapping[word_text] = ayah_value unless ayah_mapping[word_text]
        end
      end
      
      ayah_mapping
    end

    def find_ayah_for_word(word_text, word_id, line_hash, ayah_mapping)
      # Try to find ayah from multiple sources
      # 1. Check if word text matches ayah mapping from HTML
      if ayah_mapping[word_text]
        return ayah_mapping[word_text]
      end
      
      # 2. Check if word is an ayah number (Arabic numerals)
      # Arabic numerals: ٠ ١ ٢ ٣ ٤ ٥ ٦ ٧ ٨ ٩
      arabic_numerals = /[٠١٢٣٤٥٦٧٨٩]+/
      if word_text.match?(arabic_numerals) && word_text.strip.length < 5
        # This might be an ayah number, try to determine surah
        current_surah = nil
        
        # Look for surah_number in line_hash
        current_surah = line_hash['surah_number'] || line_hash[:surah_number]
        
        # If not in line, we might need to track from previous lines
        # For now, return nil and we'll improve this
      end
      
      nil
    end

    def save_page_data(mushaf, page_number, page_data, word_data, ayah_mapping = {})
      ActiveRecord::Base.transaction do
        # Find or create page - verify we're saving to the correct position
        page = mushaf.pages.find_or_initialize_by(position: page_number)
        
        Rails.logger.info "Saving page data: position=#{page_number}, page.id=#{page.id}, new_record?=#{page.new_record?}"
        
        # Check if page already exists and warn if we're overwriting
        if !page.new_record?
          existing_lines_count = page.lines.count
          Rails.logger.warn "Page #{page_number} already exists with #{existing_lines_count} lines - will overwrite"
        end
        
        page.save! if page.new_record?

        # Delete existing lines and words for this page to avoid duplicates
        page.lines.destroy_all

        # Sort page_data by line_number
        sorted_lines = page_data.sort_by { |line| line['line_number'] || line[:line_number] || 0 }
        
        # Track current surah for ayah assignment
        current_surah = nil
        
        sorted_lines.each do |line_hash|
          line = page.lines.build(
            position: line_hash['line_number'] || line_hash[:line_number] || 0
          )
          line.save!

          # For ayah lines, extract words based on first_word_id and last_word_id
          line_type = line_hash['line_type'] || line_hash[:line_type]
          
          # Update current surah if this line has surah_number
          surah_num = line_hash['surah_number'] || line_hash[:surah_number]
          current_surah = surah_num if surah_num
          
          if line_type == 'ayah'
            first_word_id = line_hash['first_word_id'] || line_hash[:first_word_id]
            last_word_id = line_hash['last_word_id'] || line_hash[:last_word_id]
            
            if first_word_id && last_word_id
              word_position = 1
              current_ayah = nil
              
              # Get words in range - word_data keys might not be sequential
              # So we need to get all keys in the range and sort them
              word_ids_in_range = []
              (first_word_id.to_i..last_word_id.to_i).each do |word_id|
                word_key = word_id.to_s
                if word_data.key?(word_key) || word_data.key?(word_key.to_sym)
                  word_ids_in_range << word_id
                end
              end
              
              # Sort word IDs to maintain order
              word_ids_in_range.sort!
              
              word_ids_in_range.each do |word_id|
                word_key = word_id.to_s
                word_text = word_data[word_key] || word_data[word_key.to_sym]
                
                if word_text
                  word_text = word_text.to_s
                  
                  # Try to determine ayah from multiple sources
                  ayah = find_ayah_for_word(word_text, word_id, line_hash, ayah_mapping)
                  
                  # If no ayah found, check if this word is an ayah number marker
                  if !ayah && word_text.match?(/[٠١٢٣٤٥٦٧٨٩]+/) && word_text.strip.length < 5
                    # This is likely an ayah number - try to construct ayah from current surah
                    if current_surah
                      # Convert Arabic numerals to regular numbers
                      arabic_to_english = {
                        '٠' => '0', '١' => '1', '٢' => '2', '٣' => '3', '٤' => '4',
                        '٥' => '5', '٦' => '6', '٧' => '7', '٨' => '8', '٩' => '9'
                      }
                      ayah_num = word_text.strip.chars.map { |c| arabic_to_english[c] || c }.join
                      if ayah_num.match?(/^\d+$/)
                        ayah = "#{current_surah}:#{ayah_num}"
                        current_ayah = ayah
                      end
                    end
                  elsif current_ayah
                    # Use the ayah from previous word (ayah number marker)
                    ayah = current_ayah
                  end
                  
                  # Preserve the word content including any ayah ending marks (preserve all characters)
                  line.words.create!(
                    position: word_position,
                    content: word_text,
                    ayah: ayah
                  )
                  word_position += 1
                end
              end
            end
          elsif line_type == 'surah_name'
            # For surah name lines, skip creating words
          elsif line_type == 'basmallah'
            # For basmallah, create a single word entry
            line.words.create!(
              position: 1,
              content: '﷽',
              ayah: nil
            )
          end
        end

        page.save!
        page
      end
    end

    def scrape_page(page_number, mushaf)
      Rails.logger.info "Starting to scrape page #{page_number}..."
      puts "Fetching URL: #{BASE_URL}#{page_number}"
      
      html_content = fetch_page(page_number)
      
      # Verify we got the right page by checking for page number in HTML
      if html_content.include?("Page #{page_number}") || html_content.include?("page #{page_number}")
        Rails.logger.info "Verified page #{page_number} in HTML title"
      else
        Rails.logger.warn "Warning: Could not verify page #{page_number} in HTML - might be cached/wrong page"
      end
      
      data = extract_javascript_data(html_content)
      
      # Verify the data is actually different (check first word ID of first ayah line)
      if data && data[:page_data] && page_number > 1
        first_ayah_line = data[:page_data].find { |line| line['line_type'] == 'ayah' || line[:line_type] == 'ayah' }
        if first_ayah_line
          first_word_id = first_ayah_line['first_word_id'] || first_ayah_line[:first_word_id]
          # For page 1, first_word_id should be 1. For subsequent pages, it should be different
          # If it's still 1, the data might be cached/duplicate
          if first_word_id == 1 && page_number > 1
            Rails.logger.error "ERROR: Page #{page_number} has first_word_id=1, same as page 1. Data may be incorrect!"
            Rails.logger.error "The website may be serving cached data or loading data via JavaScript."
            Rails.logger.error "You may need to use a headless browser (Selenium/Puppeteer) to get the correct data."
          end
        end
      end
      
      if data.nil?
        raise "Could not extract data from page #{page_number}"
      end

      save_page_data(mushaf, page_number, data[:page_data], data[:word_data], data[:ayah_mapping] || {})
      
      Rails.logger.info "✓ Successfully completed page #{page_number}"
      puts "✓ Completed page #{page_number} (#{Time.now})"
      
      # Small delay between pages to be respectful
      sleep(2)
    rescue => e
      Rails.logger.error "✗ Error processing page #{page_number}: #{e.message}"
      puts "✗ Error processing page #{page_number}: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      raise
    end

    # Main execution
    puts "=" * 80
    puts "Starting mushaf layout scraper"
    puts "Mushaf Title: #{MUSHAF_TITLE}"
    
    # Find or create the mushaf
    mushaf = Mushaf.find_or_create_by!(title: MUSHAF_TITLE)
    puts "Mushaf ID: #{mushaf.id}"
    puts "Total pages: #{TOTAL_PAGES}"
    puts "Pages per batch: #{PAGES_PER_BATCH}"
    puts "Delay between batches: #{DELAY_BETWEEN_BATCHES / 60} minutes"
    puts "=" * 80
    puts

    start_time = Time.now
    
    (1..TOTAL_PAGES).each_slice(PAGES_PER_BATCH).with_index do |batch, batch_index|
      batch_start = batch.first
      batch_end = batch.last
      
      puts "-" * 80
      puts "Processing batch #{batch_index + 1}: pages #{batch_start} to #{batch_end}"
      puts "-" * 80
      
      batch.each do |page_number|
        begin
          scrape_page(page_number, mushaf)
        rescue => e
          puts "Failed to process page #{page_number}, continuing..."
          Rails.logger.error "Failed page #{page_number}: #{e.message}"
          # Continue with next page even if one fails
        end
      end
      
      # Wait 10 minutes between batches (except after the last batch)
      unless batch.last == TOTAL_PAGES
        wait_minutes = DELAY_BETWEEN_BATCHES / 60
        puts
        puts "Batch completed. Waiting #{wait_minutes} minutes before next batch..."
        puts "Resume at: #{Time.now + DELAY_BETWEEN_BATCHES}"
        puts
        
        DELAY_BETWEEN_BATCHES.times do |i|
          sleep(1)
          print "\r#{((DELAY_BETWEEN_BATCHES - i) / 60.0).round(1)} minutes remaining...  "
          STDOUT.flush
        end
        puts "\n"
      end
    end
    
    end_time = Time.now
    duration = end_time - start_time
    
    puts "=" * 80
    puts "Scraping completed!"
    puts "Total duration: #{(duration / 60).round(2)} minutes"
    puts "Completed at: #{end_time}"
    puts "=" * 80
  end
end

