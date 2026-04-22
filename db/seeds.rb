# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

RecitationCatalogImporter.import!

# Indo-Pak 13-line mushaf (id 2): juz + surah boundaries from `react-native/segments.json` (Django export mushaf id 1).
# Page offset is rasterized into MushafSegment#start_page / #end_page (set non-zero if fixture pages drift).
if Mushaf.exists?(id: 2)
  MushafSegment.import_from_segments_json!(
    target_mushaf_id: 2,
    source_fixture_mushaf_id: 1,
    page_offset: 0,
    categories: %w[juz surah]
  )
end
