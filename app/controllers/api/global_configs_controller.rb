# frozen_string_literal: true

class Api::GlobalConfigsController < ApplicationController
  # GET /api/global_config — public; returns { "min_ios_version" => "…", ... }.
  def show
    render json: GlobalConfig.as_client_json
  end
end
