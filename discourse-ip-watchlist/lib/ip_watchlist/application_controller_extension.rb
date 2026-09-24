# frozen_string_literal: true

module ::IpWatchlist
  module ApplicationControllerExtension
    def ip_watchlist_store_referrer
      return unless defined?(SiteSetting) && SiteSetting.ip_watchlist_enabled

      ::RequestStore.store[:ip_watchlist_referrer] = request&.referer
      # Discourse only persists users.ip_address on a *later* request
      # (Scheduler::Defer in the current-user provider), so by the time
      # :user_logged_in fires the user record still carries the previous IP.
      # Remember the IP of the request that actually performed the login.
      ::RequestStore.store[:ip_watchlist_ip] = request&.remote_ip
    rescue StandardError
      # Never break a request because of referrer capture.
    end
  end
end
