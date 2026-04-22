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

  # GET /api/mushafs/:id/segments?category=juz|surah
  def segments
    mushaf = Mushaf.find(params[:id])
    rel = mushaf.mushaf_segments.order(:category, :category_position)
    if params[:category].present?
      c = params[:category].to_s.downcase
      return render json: { error: "category must be juz or surah" }, status: :bad_request unless %w[juz surah].include?(c)

      rel = rel.where(category: c)
    end

    render json: {
      mushaf_id: mushaf.id,
      segments: rel.map do |s|
        {
          id: s.id,
          category: s.category,
          category_position: s.category_position,
          title: s.title,
          start_page: s.start_page,
          end_page: s.end_page
        }
      end
    }
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

  # GET …/mushafs/:id/preceding_surah_carry?page_position=N
  # Surah carried onto page N from layout: nearest page < N that has any line with
  # surah_header_position > 0, then forward-scan that page’s lines (same as Verser client).
  def preceding_surah_carry
    mushaf = Mushaf.find(params[:id])
    page_position = params.require(:page_position).to_i
    if page_position < 1
      return render json: { error: "page_position must be >= 1" }, status: :bad_request
    end
    if page_position <= 1
      return render json: { surah: nil, source_page_position: nil }
    end

    prev_page_pos = Line.unscoped
      .joins(:page)
      .where(pages: { mushaf_id: mushaf.id })
      .where("pages.position < ?", page_position)
      .where("lines.surah_header_position > ?", 0)
      .maximum("pages.position")

    if prev_page_pos.nil?
      return render json: { surah: nil, source_page_position: nil }
    end

    page = mushaf.pages.find_by(position: prev_page_pos)
    unless page
      return render json: { error: "Source page not found" }, status: :not_found
    end

    carry = nil
    page.lines.order(:position).each do |line|
      sh = line.surah_header_position.to_i
      carry = sh if sh > 0
    end

    render json: { surah: carry, source_page_position: prev_page_pos }
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :bad_request
  end
end
