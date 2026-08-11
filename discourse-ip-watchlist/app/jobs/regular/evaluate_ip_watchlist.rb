# frozen_string_literal: true

module Jobs
  class EvaluateIpWatchlist < ::Jobs::Base
    sidekiq_options queue: "low"

    def execute(args)
      return unless SiteSetting.ip_watchlist_enabled

      ::IpWatchlist::Evaluator.evaluate!(
        user_id: args[:user_id],
        ip_address: args[:ip_address],
        referrer: args[:referrer],
      )
    end
  end
end
