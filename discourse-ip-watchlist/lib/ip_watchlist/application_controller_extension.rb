# frozen_string_literal: true

module ::IpWatchlist
  module ApplicationControllerExtension
    def ip_watchlist_store_referrer
      return unless defined?(SiteSetting) && SiteSetting.ip_watchlist_enabled
      RequestStore.store[:ip_watchlist_referrer] = request&.referer
    rescue StandardError
      # Never break a request because of referrer capture.
    end
  end
end
