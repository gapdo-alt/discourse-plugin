# frozen_string_literal: true

module ::IpWatchlist
  module ApplicationControllerExtension
    extend ActiveSupport::Concern

    prepended do
      before_action :ip_watchlist_store_referrer
    end

    def ip_watchlist_store_referrer
      return unless SiteSetting.ip_watchlist_enabled
      RequestStore.store[:ip_watchlist_referrer] = request&.referer
    end
  end
end
