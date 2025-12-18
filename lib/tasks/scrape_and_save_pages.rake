namespace :scrape do
  desc "Scrape all mushaf pages from qul.tarteel.ai and save to database (847 pages, 100 per batch, 5 min delay)"
  task save_all_pages: :environment do
    require 'nokogiri'
    require 'net/http'
    require 'openssl'
    require 'uri'
    require 'json'
    require 'set'

    BASE_URL = 'https://qul.tarteel.ai/resources/mushaf-layout/313?page='
    TOTAL_PAGES = 847
    PAGES_PER_BATCH = 100
    DELAY_BETWEEN_BATCHES = 300 # 5 minutes in seconds
    MUSHAF_TITLE = "Indopak 13 lines layout(Taj company)"

    def fetch_page(page_number)
      url = "#{BASE_URL}#{page_number}"
      uri = URI(url)
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      request['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      request['Accept-Language'] = 'en-US,en;q=0.9'
      
      response = http.request(request)
      
      if response.code != '200'
        raise "HTTP Error: #{response.code} for page #{page_number}"
      end
      
      response.body
    rescue => e
      Rails.logger.error "Error fetching page #{page_number}: #{e.message}"
      raise
    end

    def clean_text(text)
      text.gsub(/\s+/, ' ').strip
    end

    def extract_lines_from_html(html_content)
      lines = []
      doc = Nokogiri::HTML(html_content)
      
      # Find the container that holds all lines (#run-preview)
      preview_container = doc.css('#run-preview').first
      
      if preview_container
        # Get direct child divs with line-related classes
        line_elements = preview_container.children.select do |child|
          child.name == 'div' && child['class'] && 
          (child['class'].include?('line') || child['class'].include?('ayah') || 
           child['class'].include?('surah-name') || child['class'].include?('basmallah'))
        end
        
        # If we didn't get enough direct children, try XPath or get all line divs
        if line_elements.length < 13
          xpath_results = preview_container.xpath('./div[contains(@class, "line") or contains(@class, "ayah") or contains(@class, "surah-name") or contains(@class, "basmallah")]')
          line_elements = xpath_results if xpath_results.length > line_elements.length
        end
        
        # If still not enough, get all line divs within preview_container
        if line_elements.length < 13
          all_line_divs = preview_container.css('div.line, div.ayah, div.surah-name, div.basmallah')
          line_elements = all_line_divs.select do |div|
            parent = div.parent
            parent == preview_container || 
            (parent.name == 'div' && !(parent['class'] || '').match?(/line|ayah|surah|basmallah/))
          end
        end
        
        # Extract text from each line element
        line_elements.first(13).each do |line_element|
          line_text = clean_text(line_element.text)
          if line_text.length > 0
            lines << line_text
          end
        end
      else
        # Fallback: Look for Arabic text anywhere in the body
        body = doc.css('body').first
        if body
          potential_lines = body.css('div').select do |div|
            text = clean_text(div.text)
            text.match?(/[\u0600-\u06FF]/) && text.length > 10 && 
            !text.include?('Developer Resources') && 
            !text.include?('Mushaf Layout')
          end
          
          # Get unique lines, prioritizing longer ones
          seen_texts = Set.new
          potential_lines.each do |div|
            text = clean_text(div.text)
            if text.length > 10 && text.length < 500 && text.match?(/[\u0600-\u06FF]{5,}/)
              next if seen_texts.include?(text)
              is_substring = lines.any? { |existing| existing.include?(text) && existing.length > text.length }
              next if is_substring
              lines.reject! { |existing| text.include?(existing) && text.length > existing.length }
              lines << text
              seen_texts.add(text)
            end
            break if lines.length >= 13
          end
        end
      end
      
      lines.first(13)
    end

    def split_arabic_text_into_words(text)
      # Split Arabic text into words
      # Arabic words are separated by spaces, but we need to be careful with diacritics
      words = text.split(/\s+/).reject(&:empty?)
      words
    end

    def save_page_to_database(mushaf, page_number, lines)
      ActiveRecord::Base.transaction do
        # Find or create page
        page = mushaf.pages.find_or_initialize_by(position: page_number)
        page.save! if page.new_record?
        
        # Delete existing lines and words for this page to avoid duplicates
        page.lines.destroy_all
        
        # Save each line with its words
        lines.each_with_index do |line_text, line_index|
          line = page.lines.create!(position: line_index + 1)
          
          # Split line into words
          words = split_arabic_text_into_words(line_text)
          
          # Save each word
          words.each_with_index do |word_text, word_index|
            line.words.create!(
              position: word_index + 1,
              content: word_text,
              ayah: nil # We don't have ayah info from the HTML extraction
            )
          end
        end
        
        page
      end
    end

    def scrape_and_save_page(page_number, mushaf)
      Rails.logger.info "Scraping page #{page_number}..."
      puts "Processing page #{page_number}..."
      
      html_content = fetch_page(page_number)
      lines = extract_lines_from_html(html_content)
      
      if lines.empty?
        Rails.logger.warn "No lines found for page #{page_number}"
        puts "⚠️  Warning: No lines found for page #{page_number}"
        return nil
      end
      
      page = save_page_to_database(mushaf, page_number, lines)
      
      word_count = page.lines.sum { |l| l.words.count }
      puts "✓ Saved page #{page_number}: #{lines.length} lines, #{word_count} words"
      Rails.logger.info "✓ Saved page #{page_number}: #{lines.length} lines, #{word_count} words"
      
      # Small delay between pages to be respectful
      sleep(1)
      
      page
    rescue => e
      Rails.logger.error "✗ Error processing page #{page_number}: #{e.message}"
      puts "✗ Error processing page #{page_number}: #{e.message}"
      puts e.backtrace.first(3).join("\n")
      nil
    end

    # Main execution
    puts "=" * 80
    puts "Starting mushaf page scraper and database saver"
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
          scrape_and_save_page(page_number, mushaf)
        rescue => e
          puts "Failed to process page #{page_number}, continuing..."
          Rails.logger.error "Failed page #{page_number}: #{e.message}"
          # Continue with next page even if one fails
        end
      end
      
      # Wait 5 minutes between batches (except after the last batch)
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

  desc "Insert 2 proxy lines before a specified line on a page"
  task :insert_proxy_lines, [:page_number] => :environment do |_t, args|
    MUSHAF_TITLE = "Indopak 13 lines layout(Taj company)"
    
    page_number = (args[:page_number] || 1).to_i
    
    # Find the mushaf and page
    mushaf = Mushaf.find_by(title: MUSHAF_TITLE)
    unless mushaf
      puts "Error: Mushaf '#{MUSHAF_TITLE}' not found"
      exit 1
    end
    
    page = mushaf.pages.find_by(position: page_number)
    unless page
      puts "Error: Page #{page_number} not found"
      exit 1
    end
    
    # Get all lines ordered by position
    lines = page.lines.order(:position).to_a
    
    if lines.empty?
      puts "Error: No lines found for page #{page_number}"
      exit 1
    end
    
    # Display current lines
    puts "=" * 80
    puts "Page #{page_number} - Current Lines"
    puts "=" * 80
    lines.each do |line|
      word_count = line.words.count
      preview = line.words.pluck(:content).join(' ')[0..60]
      puts "#{line.position.to_s.rjust(3)}. [#{word_count} words] #{preview}#{preview.length == 60 ? '...' : ''}"
    end
    puts "=" * 80
    puts
    
    # Prompt for line number
    print "Enter the line number BEFORE which to insert 2 proxy lines (1-#{lines.length + 1}): "
    target_line_num = $stdin.gets.chomp.to_i
    
    if target_line_num < 1 || target_line_num > lines.length + 1
      puts "Error: Invalid line number. Must be between 1 and #{lines.length + 1}"
      exit 1
    end
    
    puts
    puts "Inserting 2 proxy lines before line #{target_line_num}..."
    puts
    
    # Perform the insertion
    ActiveRecord::Base.transaction do
      # First, update positions for all lines that come after the insertion point
      # Lines at position >= target_line_num need to be shifted by 2
      lines_to_update = page.lines.where('position >= ?', target_line_num).order(:position)
      
      # Update in reverse order to avoid position conflicts
      lines_to_update.reverse.each do |line|
        new_position = line.position + 2
        line.update_column(:position, new_position)
      end
      
      # Now insert 2 proxy lines at positions target_line_num and target_line_num + 1
      page.lines.create!(position: target_line_num)
      page.lines.create!(position: target_line_num + 1)
      
      puts "✓ Successfully inserted 2 proxy lines at positions #{target_line_num} and #{target_line_num + 1}"
      puts "✓ Updated positions for #{lines_to_update.count} existing lines"
    end
    
    # Display updated lines
    puts
    puts "=" * 80
    puts "Page #{page_number} - Updated Lines"
    puts "=" * 80
    page.lines.reload.order(:position).each do |line|
      word_count = line.words.count
      if word_count == 0
        puts "#{line.position.to_s.rjust(3)}. [PROXY LINE - empty]"
      else
        preview = line.words.pluck(:content).join(' ')[0..60]
        puts "#{line.position.to_s.rjust(3)}. [#{word_count} words] #{preview}#{preview.length == 60 ? '...' : ''}"
      end
    end
    puts "=" * 80
    puts
    puts "✓ Done!"
  end
end

