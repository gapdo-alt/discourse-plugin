# frozen_string_literal: true

module Jobs
  class CleanIpWatchlist < ::Jobs::Scheduled
    every 1.day

    def execute(_args = nil)
      return unless SiteSetting.ip_watchlist_enabled

      days = SiteSetting.ip_watchlist_retention_days.to_i
      return if days <= 0

      cutoff = days.days.ago

      # An IP counts as "promoted" either because it has an enforcement rule or
      # because it was put into an IP group -- both assign Discourse groups, so
      # neither may be dropped by the retention sweep.
      promoted_ips =
        IpWatchlistEnforcement.distinct.pluck(:ip_address) |
          IpWatchlistGroupMembership.distinct.pluck(:ip_address)

      scope = IpWatchlistEntry.where("last_seen_at < ?", cutoff)
      scope = scope.where.not(ip_address: promoted_ips) if promoted_ips.present?
      scope.delete_all
    end
  end
end
