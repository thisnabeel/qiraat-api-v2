class Api::NarratorsController < ApplicationController
  def index
    @narrators = Narrator.includes(:region, narrator: :region)
    render json: @narrators.as_json(include: {
      narrator: {
        only: [:id, :title, :highlight_color],
        include: {
          region: {
            only: [:id, :title]
          }
        }
      },
      region: {
        only: [:id, :title]
      }
    })
  end
end
