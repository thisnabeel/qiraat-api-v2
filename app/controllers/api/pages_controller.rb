class Api::PagesController < ApplicationController
  def show
    @mushaf = Mushaf.find(params[:mushaf_id])
    @page = @mushaf.pages.includes(lines: :words).find_by(position: params[:id])
    return render json: { error: "Page not found" }, status: :not_found unless @page

    render json: page_json(@page)
  end

  def insert_surah_header
    @mushaf = Mushaf.find(params[:mushaf_id])
    @page = @mushaf.pages.includes(lines: :words).find_by(position: params[:id])
    return render json: { error: "Page not found" }, status: :not_found unless @page
    unless @mushaf.id == 2
      return render json: { error: "Only mushaf 2 supports header insert" }, status: :unprocessable_entity
    end

    insert_at = params.require(:insert_at_position).to_i
    surah = params.require(:surah_number).to_i

    @page.insert_surah_header_block!(insert_at_position: insert_at, surah_number: surah)
    render json: page_json(@page.reload)
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :bad_request
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # PATCH body: { "updates": [{ "word_id": 1, "ayah": "2:255" }, ...] } — only words on this page.
  def bulk_update_ayahs
    @mushaf = Mushaf.find(params[:mushaf_id])
    unless @mushaf.id == 2
      return render json: { error: "Only mushaf 2 supports bulk ayah update" }, status: :unprocessable_entity
    end
    @page = @mushaf.pages.includes(lines: :words).find_by(position: params[:id])
    return render json: { error: "Page not found" }, status: :not_found unless @page

    updates = params.require(:updates)
    unless updates.is_a?(Array) && updates.any?
      return render json: { error: "updates must be a non-empty array" }, status: :bad_request
    end

    allowed_ids = @page.lines.joins(:words).pluck("words.id").to_set

    ApplicationRecord.transaction do
      updates.each do |raw|
        p = raw.is_a?(ActionController::Parameters) ? raw : ActionController::Parameters.new(raw)
        u = p.permit(:word_id, :ayah)
        wid = u[:word_id].to_i
        next unless allowed_ids.include?(wid)

        ayah_val = u[:ayah].nil? ? "" : u[:ayah].to_s
        Word.where(id: wid).update_all(ayah: ayah_val)
      end
    end

    @page.reload
    render json: page_json(@page)
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :bad_request
  end

  private

  # Serialize lines in mushaf reading order (by line.position). Nested as_json can follow
  # association load order from preloads; clients render the lines array top-to-bottom.
  def page_json(page)
    hash = page.as_json(only: [:id, :position])
    hash["lines"] = page.lines.sort_by(&:position).map do |line|
      line.as_json(
        include: {
          words: {
            only: [:id, :position, :content, :ayah]
          }
        },
        only: [:id, :position, :surah_header_position]
      )
    end
    hash
  end
end
