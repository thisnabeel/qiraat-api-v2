namespace :print do
  desc "Print each line from a mushaf layout page using Nokogiri"
  task :page_lines, [:page_number] => :environment do |_t, args|
    require 'nokogiri'
    require 'net/http'
    require 'openssl'
    require 'uri'
    require 'json'
    require 'set'

    page_number = (args[:page_number] || 4).to_i
    BASE_URL = 'https://qul.tarteel.ai/resources/mushaf-layout/313?page='

    def fetch_page(page_number)
      url = "#{BASE_URL}#{page_number}"
      uri = URI(url)
      
      puts "Fetching: #{url}"
      
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
      puts "Error fetching page #{page_number}: #{e.message}"
      raise
    end

    def clean_text(text)
      # Remove excessive whitespace and normalize
      text.gsub(/\s+/, ' ').strip
    end

    def extract_balanced(content, start_pos, open_char, close_char)
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

    def extract_lines_from_html(html_content, page_number)
      lines = []
      
      # Check if there are any API endpoints or data URLs in the HTML
      # The page might load data via fetch/axios
      api_urls = html_content.scan(/['"]([^'"]*\/api[^'"]*page[^'"]*)['"]/i)
      data_urls = html_content.scan(/['"]([^'"]*\/data[^'"]*page[^'"]*)['"]/i)
      
      if api_urls.any? || data_urls.any?
        puts "Found potential API/data URLs in HTML (page might load data dynamically)"
      end
      
      # Method 1: Try to extract from JavaScript data and reconstruct (most reliable)
      page_data_match = html_content.match(/const pageData = (\[.*?\])/m)
      word_data_match = html_content.match(/const wordData = (\{.*?\})/m)
      
      if page_data_match && word_data_match
        begin
          # Extract balanced brackets/braces (more reliable than simple regex)
          page_data_start = html_content.index('const pageData =')
          word_data_start = html_content.index('const wordData =')
          
          # Find array/object start positions
          page_data_array_start = html_content.index('[', page_data_start)
          word_data_object_start = html_content.index('{', word_data_start)
          
          # Extract balanced brackets
          page_data_js = extract_balanced(html_content, page_data_array_start, '[', ']')
          word_data_js = extract_balanced(html_content, word_data_object_start, '{', '}')
          
          if page_data_js && word_data_js
            # Convert JavaScript to JSON
            page_data_json = page_data_js.gsub(/([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:/, '\1"\2":').gsub(/'/, '"')
            word_data_json = word_data_js.gsub(/'/, '"')
            
            page_data = JSON.parse(page_data_json)
            word_data = JSON.parse(word_data_json)
            
            # Check if we got the right page by looking at first word ID
            first_ayah_line = page_data.find { |line| (line['line_type'] || line[:line_type]) == 'ayah' }
            if first_ayah_line
              first_word_id = first_ayah_line['first_word_id'] || first_ayah_line[:first_word_id]
              if first_word_id == 1 && page_number > 1
                puts "⚠️  WARNING: Extracted data shows first_word_id=1 (page 1 data)"
                puts "   The page loads data dynamically via JavaScript."
                puts "   To get the correct page data, you may need to use a headless browser"
                puts "   (e.g., Selenium, Puppeteer) or find the API endpoint that serves the data."
                puts
                puts "   Attempting to extract rendered text from HTML instead..."
                puts
                # Don't use this data, fall through to HTML extraction
                page_data = nil
                word_data = nil
              end
            end
            
            # Only use this data if it's valid (not page 1 data when requesting other pages)
            if page_data && word_data
              # Reconstruct lines in order
              sorted_lines = page_data.sort_by { |line| (line['line_number'] || line[:line_number] || 0).to_i }
              
              sorted_lines.each do |line_hash|
              line_type = line_hash['line_type'] || line_hash[:line_type]
              
              case line_type
              when 'surah_name'
                surah_num = line_hash['surah_number'] || line_hash[:surah_number]
                lines << "سورۃ #{surah_num}" # Simplified surah name
              when 'ayah'
                first_word_id = line_hash['first_word_id'] || line_hash[:first_word_id]
                last_word_id = line_hash['last_word_id'] || line_hash[:last_word_id]
                
                if first_word_id && last_word_id
                  word_texts = []
                  # Get all word IDs in range - word_data keys might not be sequential
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
                    word_texts << word_text if word_text
                  end
                  line_text = word_texts.join(' ')
                  lines << line_text if line_text && !line_text.strip.empty?
                end
              when 'basmallah'
                lines << '﷽'
              end
            end
            end
          end
        rescue => e
          puts "Warning: Could not parse JavaScript data: #{e.message}"
        end
      end
      
      # Method 2: Extract from fully rendered HTML (after JavaScript execution)
      doc = Nokogiri::HTML(html_content)
      
      # Find the container that holds all lines (#run-preview)
      preview_container = doc.css('#run-preview').first
      
      if preview_container
        puts "Found #run-preview container"
        
        # Get all divs within the preview container
        all_divs = preview_container.css('div')
        puts "Found #{all_divs.length} divs within #run-preview"
        
        # Get direct child divs with line-related classes
        line_elements = preview_container.children.select do |child|
          child.name == 'div' && child['class'] && 
          (child['class'].include?('line') || child['class'].include?('ayah') || 
           child['class'].include?('surah-name') || child['class'].include?('basmallah'))
        end
        
        puts "Found #{line_elements.length} direct child line divs"
        
        # If we didn't get enough direct children, try XPath or get all line divs
        if line_elements.length < 13
          xpath_results = preview_container.xpath('./div[contains(@class, "line") or contains(@class, "ayah") or contains(@class, "surah-name") or contains(@class, "basmallah")]')
          puts "XPath found #{xpath_results.length} line divs"
          line_elements = xpath_results if xpath_results.length > line_elements.length
        end
        
        # If still not enough, get all line divs within preview_container
        if line_elements.length < 13
          all_line_divs = preview_container.css('div.line, div.ayah, div.surah-name, div.basmallah')
          puts "CSS selector found #{all_line_divs.length} line divs"
          # Filter to top-level only (not nested)
          line_elements = all_line_divs.select do |div|
            parent = div.parent
            parent == preview_container || 
            (parent.name == 'div' && !(parent['class'] || '').match?(/line|ayah|surah|basmallah/))
          end
          puts "After filtering, found #{line_elements.length} top-level line divs"
        end
        
        # Extract text from each line element
        line_elements.first(13).each do |line_element|
          # Get all text content from this line (including all nested children)
          line_text = clean_text(line_element.text)
          if line_text.length > 0
            lines << line_text
          end
        end
        
        puts "Extracted #{lines.length} lines from HTML"
      else
        puts "Could not find #run-preview container in HTML"
        
        # Fallback: Look for Arabic text anywhere in the body
        # Sometimes the text is rendered but not in the expected container
        body = doc.css('body').first
        if body
          # Look for divs with Arabic text that might be lines
          potential_lines = body.css('div').select do |div|
            text = clean_text(div.text)
            text.match?(/[\u0600-\u06FF]/) && text.length > 10 && 
            !text.include?('Developer Resources') && 
            !text.include?('Mushaf Layout')
          end
          
          # Get unique lines, prioritizing longer ones (they're more complete)
          seen_texts = Set.new
          potential_lines.each do |div|
            text = clean_text(div.text)
            # Only add if it looks like a Quranic line (has Arabic and reasonable length)
            if text.length > 10 && text.length < 500 && text.match?(/[\u0600-\u06FF]{5,}/)
              # Skip if we've already seen this exact text
              next if seen_texts.include?(text)
              
              # Check if this is a substring of an existing line (skip it)
              is_substring = lines.any? { |existing| existing.include?(text) && existing.length > text.length }
              next if is_substring
              
              # Remove any existing lines that are substrings of this one (keep the longer one)
              lines.reject! { |existing| text.include?(existing) && text.length > existing.length }
              
              lines << text
              seen_texts.add(text)
            end
            break if lines.length >= 13
          end
          
          puts "Found #{lines.length} lines from fallback extraction"
        end
      end
      
      # Return exactly as extracted - no filtering, no deduplication
      # Just take the first 13 lines
      lines.first(13)
    end

    def reconstruct_lines_from_data(page_data, word_data)
      lines = []
      sorted_lines = page_data.sort_by { |line| (line['line_number'] || line[:line_number] || 0).to_i }
      
      sorted_lines.each do |line_hash|
        line_type = line_hash['line_type'] || line_hash[:line_type]
        
        case line_type
        when 'surah_name'
          surah_num = line_hash['surah_number'] || line_hash[:surah_number]
          lines << "سورۃ #{surah_num}"
        when 'ayah'
          first_word_id = line_hash['first_word_id'] || line_hash[:first_word_id]
          last_word_id = line_hash['last_word_id'] || line_hash[:last_word_id]
          
          if first_word_id && last_word_id
            word_texts = []
            (first_word_id.to_i..last_word_id.to_i).each do |word_id|
              word_key = word_id.to_s
              word_text = word_data[word_key] || word_data[word_key.to_sym]
              word_texts << word_text if word_text
            end
            line_text = word_texts.join(' ')
            lines << line_text if line_text && !line_text.strip.empty?
          end
        when 'basmallah'
          lines << '﷽'
        end
      end
      
      lines
    end

    puts "=" * 80
    puts "Printing lines from page #{page_number}"
    puts "=" * 80
    puts

    begin
      html_content = fetch_page(page_number)
      lines = extract_lines_from_html(html_content, page_number)
      
      if lines.empty?
        puts "No lines found. The page structure might have changed."
        puts "HTML content length: #{html_content.length} bytes"
        puts
        puts "Trying to find any text content..."
        doc = Nokogiri::HTML(html_content)
        # Look for any Arabic text
        doc.css('body').each do |body|
          text = body.text
          if text.match?(/[\u0600-\u06FF]/) # Arabic Unicode range
            puts "Found Arabic text in body:"
            puts text.split("\n").reject(&:empty?).first(20).join("\n")
          end
        end
      else
        puts "Found #{lines.length} lines:"
        puts "-" * 80
        lines.each_with_index do |line, index|
          puts "#{index + 1}. #{line}"
        end
        puts "-" * 80
      end
    rescue => e
      puts "Error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
end

