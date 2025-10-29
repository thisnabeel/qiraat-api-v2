class Api::NarratorsController < ApplicationController
  def index
    @narrators = Narrator.all
    render json: @narrators
  end
end
