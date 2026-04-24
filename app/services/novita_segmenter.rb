# frozen_string_literal: true

class NovitaSegmenter
  # Segmentation can run many minutes on long surahs; Net::HTTP defaults to ~60s read timeout.
  DEFAULT_READ_TIMEOUT_S = 1200 # 20 minutes
  DEFAULT_OPEN_TIMEOUT_S = 120

  def self.call(recitation)
    read_timeout = Integer(ENV.fetch("NOVITA_SEGMENTER_READ_TIMEOUT_SECONDS", DEFAULT_READ_TIMEOUT_S))
    open_timeout = Integer(ENV.fetch("NOVITA_SEGMENTER_OPEN_TIMEOUT_SECONDS", DEFAULT_OPEN_TIMEOUT_S))

    conn = Faraday.new(url: ENV.fetch("NOVITA_SEGMENTER_URL")) do |f|
      f.options.timeout = read_timeout
      f.options.open_timeout = open_timeout
    end
    payload = {
      recitation_id: recitation.id,
      audio_url: recitation.audio_url,
      surah: recitation.surah_number,
      riwayah: recitation.riwayah_name,
      reciter: recitation.reciter_name
    }

    Rails.logger.info("[NovitaSegmenter] request payload=#{payload.to_json}")

    response = conn.post("/segment-recitation") do |req|
      req.headers["Content-Type"] = "application/json"
      req.headers["Authorization"] = "Bearer #{ENV.fetch('NOVITA_SEGMENTER_TOKEN')}"
      req.body = payload.to_json
    end

    Rails.logger.info("[NovitaSegmenter] response status=#{response.status} body=#{response.body}")

    unless response.success?
      raise "NovitaSegmenter error: #{response.status} #{response.body}"
    end

    JSON.parse(response.body)
  end
end
