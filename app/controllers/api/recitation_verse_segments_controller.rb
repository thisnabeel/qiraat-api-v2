class Api::RecitationVerseSegmentsController < ApplicationController
  before_action :set_recitation

  def index
    rows = @recitation.recitation_verse_segments.order(:start_time, :id)
    render json: rows.as_json(only: [:id, :verse, :start_time, :end_time])
  end

  def update
    list = params[:segments]
    unless list.is_a?(Array)
      render json: { error: "segments must be an array" }, status: :unprocessable_entity
      return
    end

    now = Time.current
    payload = []
    list.each do |raw|
      p = raw.is_a?(ActionController::Parameters) ? raw : ActionController::Parameters.new(raw)
      row = p.permit(:verse, :start_time, :end_time)
      verse = row[:verse].to_s
      next if verse.blank?

      st = row[:start_time].to_i
      en = row[:end_time].to_i
      payload << {
        recitation_id: @recitation.id,
        verse: verse,
        start_time: st,
        end_time: en,
        created_at: now,
        updated_at: now
      }
    end

    RecitationVerseSegment.transaction do
      @recitation.recitation_verse_segments.delete_all
      RecitationVerseSegment.insert_all!(payload) if payload.any?
    end

    head :no_content
  end

  private

  def set_recitation
    @recitation = Recitation.find(params[:recitation_id])
  end
end
