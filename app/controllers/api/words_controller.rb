class Api::WordsController < ApplicationController
  def index
    # Get words for a specific line
    if params[:line_id]
      @words = Word.where(line_id: params[:line_id]).order(:position)
      render json: @words
    else
      @words = Word.all.order(:position)
      render json: @words
    end
  end

  def show
    @word = Word.find(params[:id])
    render json: @word.as_json(include: :variations)
  end
end
