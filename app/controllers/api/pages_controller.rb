class Api::PagesController < ApplicationController
  def show
    @mushaf = Mushaf.find(params[:mushaf_id])
    @page = @mushaf.pages.includes(lines: :words).find_by(position: params[:id])

    # Lines and words eager-loaded to avoid N+1 (one query per line for words)
    render json: @page.as_json(include: { 
      lines: { 
        include: { 
          words: { 
            only: [:id, :position, :content, :ayah] 
          } 
        }, 
        only: [:id, :position] 
      } 
    }, only: [:id, :position])
  end
end
