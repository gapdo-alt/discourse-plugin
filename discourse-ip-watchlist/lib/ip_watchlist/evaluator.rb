# frozen_string_literal: true

module ::IpWatchlist
  class Evaluator
    REASON_ORG = "org_keyword"
    REASON_HOSTNAME = "hostname_keyword"
    REASON_REFERRER = "referrer"
    REASON_MANUAL = "manual"

    def self.evaluate!(user_id:, ip_address:, referrer: nil)
      new(user_id: user_id, ip_address: ip_address, referrer: referrer).evaluate!
    end

    def initialize(user_id:, ip_address:, referrer: nil)
      @user_id = user_id
      @ip_address = normalize_ip(ip_address)
      @referrer = referrer.presence
    end

    def evaluate!
      return if @ip_address.blank?

      info = fetch_ip_info
      reason = detect_reason(info)

      if reason
        IpWatchlistEntry.upsert_hit!(
          ip_address: @ip_address,
          reason: reason,
          organization: info[:organization],
          hostname: info[:hostname],
          referrer: reason == REASON_REFERRER ? @referrer : nil,
        )
      end

      GroupAssigner.assign_user_for_ip!(user_id: @user_id, ip_address: @ip_address)
    end

    private

    def normalize_ip(ip)
      return nil if ip.blank?
      IPAddr.new(ip.to_s).to_s
    rescue IPAddr::InvalidAddressError
      nil
    end

    def fetch_ip_info
      DiscourseIpInfo.get(@ip_address, resolve_hostname: true) || {}
    rescue StandardError => e
      Rails.logger.warn("[IpWatchlist] DiscourseIpInfo failed for #{@ip_address}: #{e.message}")
      {}
    end

    def detect_reason(info)
      org = info[:organization].to_s
      hostname = info[:hostname].to_s

      if Wildcard.contains_keyword?(org, SiteSetting.ip_watchlist_org_keywords_map)
        return REASON_ORG
      end

      if Wildcard.contains_keyword?(hostname, SiteSetting.ip_watchlist_hostname_keywords_map)
        return REASON_HOSTNAME
      end

      if Wildcard.match?(@referrer, SiteSetting.ip_watchlist_referrer_patterns_map)
        return REASON_REFERRER
      end

      nil
    end
  end
end
