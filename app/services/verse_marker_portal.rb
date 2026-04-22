# frozen_string_literal: true

# Password and signed session tokens for the verse-marker admin (Svelte).
# Password is read from ENV (set VERSE_MARKER_PASSWORD in production).
class VerseMarkerPortal
  SESSION_PURPOSE = "verse_marker_v1"

  class << self
    def expected_password
      ENV.fetch("VERSE_MARKER_PASSWORD", "aswaat-bro")
    end

    def password_matches?(candidate)
      return false if candidate.blank?

      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(candidate.to_s),
        ::Digest::SHA256.hexdigest(expected_password.to_s)
      )
    end

    def issue_token
      payload = { "exp" => 30.days.from_now.to_i }
      verifier.generate(payload)
    end

    def valid_token?(token)
      return false if token.blank?

      data = verifier.verify(token)
      exp = data["exp"]
      return false unless exp.is_a?(Integer)

      Time.at(exp) > Time.current
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      false
    end

    private

    def verifier
      @verifier ||= ActiveSupport::MessageVerifier.new(
        Rails.application.secret_key_base,
        digest: "SHA256",
        serializer: JSON,
        purpose: SESSION_PURPOSE
      )
    end
  end
end
