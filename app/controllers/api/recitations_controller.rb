class Api::RecitationsController < ApplicationController
  def index
    reciter = Reciter.find_by!(slug: params[:reciter_slug])
    scope = reciter.recitations.includes(:recitation_narrator, :surah).order(:surah_position, :recitation_narrator_id)
    if params[:narrator_slug].present?
      narrator = RecitationNarrator.find_by!(slug: params[:narrator_slug])
      scope = scope.where(recitation_narrator: narrator)
    end

    recitation_rows = scope.to_a
    ids = recitation_rows.map(&:id)
    marked_by_id = marked_ayah_counts_by_recitation_id(ids)

    rows = recitation_rows.map do |r|
      name_ar = r.surah&.name_ar.to_s
      {
        recitation_id: r.id,
        index: r.surah_position,
        name: name_ar.presence || "",
        url: r.audio_url,
        riwayahId: r.recitation_narrator.slug,
        riwayahLabel: r.recitation_narrator.title,
        marked_verse_count: marked_by_id[r.id] || 0
      }
    end

    render json: rows
  end

  private

  def marked_ayah_counts_by_recitation_id(recitation_ids)
    return {} if recitation_ids.empty?

    segs = RecitationVerseSegment.where(recitation_id: recitation_ids)
    segs.group_by(&:recitation_id).transform_values do |list|
      list.map(&:ayah_number).uniq.count { |n| n >= 1 }
    end
  end
end
