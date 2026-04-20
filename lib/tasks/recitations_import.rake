namespace :recitations do
  desc "Import surahs, riwayahs, and recitation tracks from db/fixtures (idempotent)"
  task import: :environment do
    RecitationCatalogImporter.import!
    puts "RecitationCatalogImporter: done."
  end
end
