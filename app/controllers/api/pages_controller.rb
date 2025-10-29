class Api::PagesController < ApplicationController
  def show
    @mushaf = Mushaf.find(params[:mushaf_id])
    @page = @mushaf.pages.find_by(position: params[:id])
    
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
