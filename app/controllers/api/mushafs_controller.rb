class Api::MushafsController < ApplicationController
  def index
    @mushafs = Mushaf.all
    render json: @mushafs
  end

  def show
    @mushaf = Mushaf.find(params[:id])
    render json: @mushaf.as_json.merge(
      total_pages: @mushaf.pages.maximum(:position) || 0,
      page_count: @mushaf.pages.count
    )
  end

  # One round-trip for clients that highlight surahs by DB banner rows (e.g. mushaf 2 header tool).
  # Returns page_position (mushaf page number) -> distinct surah_header_position values on that page.
  def surah_header_markers
    @mushaf = Mushaf.find(params[:id])
    rows = Line
      .unscope(:order)
      .joins(:page)
      .where(pages: { mushaf_id: @mushaf.id })
      .where("lines.surah_header_position > ?", 0)
      .pluck("pages.position", "lines.surah_header_position")

    by_page = {}
    rows.each do |page_pos, surah_pos|
      (by_page[page_pos] ||= []) << surah_pos
    end
    by_page.each_value(&:uniq!)

    render json: { by_page: by_page.transform_keys(&:to_s) }
  end
end
