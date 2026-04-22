# frozen_string_literal: true

class Api::Admin::VerseMarkerSessionsController < ApplicationController
  # POST /api/admin/verse_marker_session
  def create
    password = params.permit(:password)[:password].to_s
    unless VerseMarkerPortal.password_matches?(password)
      render json: { error: "invalid_password" }, status: :unauthorized
      return
    end

    render json: { token: VerseMarkerPortal.issue_token }, status: :created
  end

  # GET /api/admin/verse_marker_session — Authorization: Bearer <token>
  def show
    token = bearer_token
    unless token.present? && VerseMarkerPortal.valid_token?(token)
      render json: { ok: false }, status: :unauthorized
      return
    end

    render json: { ok: true }
  end

  private

  def bearer_token
    h = request.headers["Authorization"].to_s
    return nil unless h.start_with?("Bearer ")

    h.delete_prefix("Bearer ").strip.presence
  end
end
