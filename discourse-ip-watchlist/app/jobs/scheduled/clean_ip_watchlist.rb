# frozen_string_literal: true

module Jobs
  class CleanIpWatchlist < ::Jobs::Scheduled
    every 1.day

    def execute(_args = nil)
      return unless SiteSetting.ip_watchlist_enabled

      days = SiteSetting.ip_watchlist_retention_days.to_i
      return if days <= 0

      cutoff = days.days.ago
      enforced_ips = IpWatchlistEnforcement.distinct.pluck(:ip_address)

      scope = IpWatchlistEntry.where("last_seen_at < ?", cutoff)
      scope = scope.where.not(ip_address: enforced_ips) if enforced_ips.present?
      scope.delete_all
    end
  end
end
