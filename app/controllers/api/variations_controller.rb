class Api::VariationsController < ApplicationController
  def create
    # Find or create variation for the specific word and narrator
    # Each narrator can have at most one variation per word (override existing)
    @variation = Variation.find_or_initialize_by(
      word_id: variation_params[:word_id],
      narrator_id: variation_params[:narrator_id]
    )
    
    @variation.content = variation_params[:content]
    
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
      render json: @variations.as_json(
        include: {
          narrator: { only: [:id, :title, :highlight_color] },
          word: {
            only: [:id, :content, :position, :ayah],
            include: {
              line: {
                only: [:id, :position],
                include: {
                  page: { only: [:id, :position] }
                }
              }
            }
          }
        }
      )
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

  def variation_params
    params.require(:variation).permit(:content, :word_id, :narrator_id)
  end
end
