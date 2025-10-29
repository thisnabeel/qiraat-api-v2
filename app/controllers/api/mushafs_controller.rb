class Api::MushafsController < ApplicationController
  def index
    @mushafs = Mushaf.all
    render json: @mushafs
  end

  def show
    @mushaf = Mushaf.find(params[:id])
    render json: @mushaf
  end
end
