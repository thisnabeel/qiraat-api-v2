class Api::VariationsController < ApplicationController
  def create
    # Find or create variation for the specific word and narrator
    # Each narrator can have at most one variation per word (override existing)
    @variation = Variation.find_or_initialize_by(
      word_id: variation_params[:word_id],
      narrator_id: variation_params[:narrator_id]
    )
    
    @variation.content = variation_params[:content]
    @variation.special_characters = variation_params[:special_characters] if variation_params.key?(:special_characters)
    
    if @variation.save
      render json: @variation, status: :created
    else
      render json: { errors: @variation.errors }, status: :unprocessable_entity
    end
  end

  def index
    # Get variations for specific word IDs
    if params[:word_ids]
      word_ids = params[:word_ids].split(',').map(&:to_i)
      @variations = Variation.where(word_id: word_ids).includes(:narrator)
      render json: @variations.as_json(include: :narrator)
    elsif params[:word_id]
      # Get variations for a specific word
      @variations = Variation.where(word_id: params[:word_id]).includes(:narrator)
      render json: @variations.as_json(include: :narrator)
    else
      # Get all variations for entire mushaf (for narration changes sidebar)
      # Optional: filter by narrator_ids (comma-separated) to reduce payload
      # Optional: filter by mushaf_id to scope to a specific mushaf's pages
      @variations = Variation
        .joins(word: { line: :page })
        .includes(:narrator, word: { line: :page })
      if params[:mushaf_id].present?
        @variations = @variations.where(pages: { mushaf_id: params[:mushaf_id] })
      end
      if params[:narrator_ids].present?
        narrator_ids = params[:narrator_ids].split(',').map(&:to_i)
        @variations = @variations.where(narrator_id: narrator_ids)
      end
      @variations = @variations.order('pages.position ASC, lines.position ASC, words.position ASC')
      payload = @variations.as_json(
        include: {
          narrator: { only: [:id, :title, :highlight_color] },
          word: {
            only: [:id, :content, :position, :ayah],
            include: {
              line: {
                only: [:id, :position, :surah_header_position],
                include: {
                  page: { only: [:id, :position] }
                }
              }
            }
          }
        }
      )
      mushaf_id = params[:mushaf_id].presence&.to_i
      append_surah_numbers!(payload, mushaf_id) if mushaf_id&.positive?
      render json: payload
    end
  end

  def show
    @variation = Variation.find(params[:id])
    render json: @variation.as_json(include: [:narrator, :word])
  end

  def destroy
    @variation = Variation.find(params[:id])
    if @variation.destroy
      head :no_content
    else
      render json: { errors: @variation.errors }, status: :unprocessable_entity
    end
  end

  def destroy_by_keys
    @variation = Variation.find_by(
      word_id: params[:word_id],
      narrator_id: params[:narrator_id]
    )
    
    if @variation
      if @variation.destroy
        head :no_content
      else
        render json: { errors: @variation.errors }, status: :unprocessable_entity
      end
    else
      render json: { error: "Variation not found" }, status: :not_found
    end
  end

  private

  # Each line with surah_header_position > 0 is a surah title row; the value is the surah number.
  # Words on following lines inherit that surah until the next such header (mushaf reading order).
  def append_surah_numbers!(variations_json, mushaf_id)
    segments = Line.unscoped
                   .joins(:page)
                   .where(pages: { mushaf_id: mushaf_id })
                   .where("lines.surah_header_position > 0")
                   .order("pages.position ASC, lines.position ASC")
                   .pluck("pages.position", "lines.position", "lines.surah_header_position")

    variations_json.each do |item|
      word = item["word"]
      next unless word

      line = word["line"]
      page = line && line["page"]
      next unless line && page

      page_pos = page["position"].to_i
      line_pos = line["position"].to_i
      item["surah_number"] = surah_number_at(page_pos, line_pos, segments)
    end
  end

  def surah_number_at(page_pos, line_pos, segments)
    return 1 if segments.blank?

    idx = segments.bsearch_index do |(sp, sl, _)|
      sp > page_pos || (sp == page_pos && sl > line_pos)
    end
    chosen = if idx.nil?
               segments.last
             elsif idx.positive?
               segments[idx - 1]
             else
               nil
             end
    chosen ? chosen[2].to_i : 1
  end

  def variation_params
    # special_characters: { imalah: { indices: [], placement_by_letter: {} }, diamond: { ... } } (API may send placementByLetter; we normalize in model if needed)
    permitted = params.require(:variation).permit(:content, :word_id, :narrator_id)
    permitted[:special_characters] = params[:variation][:special_characters] if params[:variation].key?(:special_characters)
    permitted
  end
end
