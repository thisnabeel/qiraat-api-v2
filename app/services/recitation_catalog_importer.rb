class RecitationCatalogImporter
  FIXTURES_ROOT = Rails.root.join("db/fixtures")

  RECITER_META = {
    "abdul-rashid-ali-sufi" => {
      name: "Abdul Rashid Ali Sufi",
      avatar_url: ""
    }
  }.freeze

  RIWAYAH_BY_FOLDER = {
    "hafs_an_asim" => { slug: "hafs-an-asim", title: "Hafs an Asim" },
    "shubah_an_asim" => { slug: "shubah-an-asim", title: "Shu'bah an Asim" }
  }.freeze

  def self.import!
    import_surahs!
    import_riwayahs!
    import_recitation_files!
  end

  def self.import_surahs!
    path = FIXTURES_ROOT.join("surah_numbers.json")
    raise "Missing #{path}" unless path.file?

    JSON.parse(path.read).each do |pos_str, raw|
      pos = pos_str.to_i
      next if pos < 1 || pos > 114

      name_ar =
        case raw
        when String then raw
        when Hash then (raw["ar"] || raw["arabic"]).to_s
        else ""
        end

      row = Surah.find_or_initialize_by(position: pos)
      row.name_ar = name_ar
      row.save!
    end
  end

  def self.import_riwayahs!
    RIWAYAH_BY_FOLDER.each_value do |meta|
      n = RecitationNarrator.find_or_initialize_by(slug: meta[:slug])
      n.title = meta[:title]
      n.save!
    end
  end

  def self.import_recitation_files!
    recitations_root = FIXTURES_ROOT.join("recitations")
    return unless recitations_root.directory?

    RIWAYAH_BY_FOLDER.each do |folder, meta|
      dir = recitations_root.join(folder)
      next unless dir.directory?

      narrator = RecitationNarrator.find_by!(slug: meta[:slug])

      Dir.glob(dir.join("*.json")).sort.each do |path|
        reciter_slug = File.basename(path, ".json")
        meta_rec = RECITER_META[reciter_slug] || {
          name: reciter_slug.tr("-", " ").split.map(&:capitalize).join(" "),
          avatar_url: ""
        }

        reciter = Reciter.find_or_initialize_by(slug: reciter_slug)
        reciter.name = meta_rec[:name]
        reciter.avatar_url = meta_rec[:avatar_url].to_s
        reciter.save!

        list = JSON.parse(File.read(path))
        next unless list.is_a?(Array)

        list.each do |item|
          pos = item["index"].to_i
          url = item["url"].to_s
          next if pos < 1 || pos > 114 || url.blank?

          rec = Recitation.find_or_initialize_by(
            reciter: reciter,
            recitation_narrator: narrator,
            surah_position: pos
          )
          rec.audio_url = url
          rec.save!
        end
      end
    end
  end
end
