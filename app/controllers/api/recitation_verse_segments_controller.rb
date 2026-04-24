class Api::RecitationVerseSegmentsController < ApplicationController
  include VerseMarkerSessionAuthenticatable

  before_action :set_recitation, except: [:lookup]
  before_action :authenticate_verse_marker_session!, only: [:update]

  # Find a segment (and its recitation audio) by verse label, e.g. "104:5".
  # Optional: reciter_slug, narrator_slug to disambiguate when the same verse exists for multiple riwayahs.
  def lookup
    verse = params.require(:verse).to_s.strip
    if verse.blank?
      render json: { error: "verse is required" }, status: :unprocessable_entity
      return
    end

    scope = RecitationVerseSegment
      .joins(recitation: [:reciter, :recitation_narrator])
      .where(recitation_verse_segments: { verse: verse })

    if params[:reciter_slug].present?
      scope = scope.where(reciters: { slug: params[:reciter_slug] })
    end
    if params[:narrator_slug].present?
      scope = scope.where(recitation_narrators: { slug: params[:narrator_slug] })
    end

    seg = scope.includes(recitation: [:reciter, :recitation_narrator]).order("recitation_verse_segments.id ASC").first

    if seg.nil?
      render json: { error: "not_found" }, status: :not_found
      return
    end

    r = seg.recitation
    render json: {
      verse: seg.verse,
      start_time: seg.start_time / 1000.0,
      end_time: seg.end_time / 1000.0,
      recitation_id: r.id,
      surah_position: r.surah_position,
      audio_url: r.audio_url,
      reciter_slug: r.reciter.slug,
      reciter_name: r.reciter.name,
      riwayah_slug: r.recitation_narrator.slug,
      riwayah_title: r.recitation_narrator.title
    }
  end

  def index
    rows = @recitation.recitation_verse_segments.order(:start_time, :id)
    render json: rows.map(&:as_api_json)
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

      st = RecitationVerseSegment.ms_from_api_seconds(row[:start_time])
      en = RecitationVerseSegment.ms_from_api_seconds(row[:end_time])
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
