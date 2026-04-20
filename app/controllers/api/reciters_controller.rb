class Api::RecitersController < ApplicationController
  def index
    render json: Reciter.order(:name).as_json(only: [:id, :slug, :name, :avatar_url])
  end
end
