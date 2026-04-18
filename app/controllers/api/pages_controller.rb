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

  private

  def page_json(page)
    page.as_json(
      include: {
        lines: {
          include: {
            words: {
              only: [:id, :position, :content, :ayah]
            }
          },
          only: [:id, :position, :surah_header_position]
        }
      },
      only: [:id, :position]
    )
  end
end
