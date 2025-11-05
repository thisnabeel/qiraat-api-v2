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
      @variations = Variation.all.includes(:narrator, :word)
      render json: @variations.as_json(include: [:narrator, :word])
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
