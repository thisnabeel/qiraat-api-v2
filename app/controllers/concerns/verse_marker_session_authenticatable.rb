# frozen_string_literal: true

module VerseMarkerSessionAuthenticatable
  extend ActiveSupport::Concern

  private

  def authenticate_verse_marker_session!
    token = bearer_token
    unless token.present? && VerseMarkerPortal.valid_token?(token)
      render json: { error: "verse_marker_session_required" }, status: :unauthorized
    end
  end

  def bearer_token
    h = request.headers["Authorization"].to_s
    return nil unless h.start_with?("Bearer ")

    h.delete_prefix("Bearer ").strip.presence
  end
end
