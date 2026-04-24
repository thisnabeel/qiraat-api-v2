# frozen_string_literal: true

class NovitaSegmenter
  def self.call(recitation)
    conn = Faraday.new(url: ENV.fetch("NOVITA_SEGMENTER_URL"))
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
