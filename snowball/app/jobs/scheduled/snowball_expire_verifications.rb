# frozen_string_literal: true

# Daily sweep: move users whose verification is older than
# `snowball_validity_days` out of the verified group (and into the configured
# expired group).
module Jobs
  class SnowballExpireVerifications < ::Jobs::Scheduled
    every 1.day

    def execute(_args = nil)
      return unless SiteSetting.snowball_enabled
      return if SiteSetting.snowball_validity_days.to_i <= 0

      cutoff = SiteSetting.snowball_validity_days.to_i.days.ago.iso8601
      already_expired =
        UserCustomField.where(name: "snowball_expired_at").pluck(:user_id).to_set

      # snowball_verified_at is stored as an ISO8601 string in the site time
      # zone, so plain string comparison is chronological here.
      UserCustomField
        .where(name: "snowball_verified_at")
        .where("value < ?", cutoff)
        .find_each do |field|
          next if already_expired.include?(field.user_id)

          user = User.find_by(id: field.user_id)
          next if user.nil?

          ::SnowballPromoter.expire!(user)
        end
    end
  end
end
