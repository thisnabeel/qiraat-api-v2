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
end
