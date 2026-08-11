# frozen_string_literal: true

module ::IpWatchlist
  class GroupAssigner
    def self.assign_user_for_ip!(user_id:, ip_address:)
      user = User.find_by(id: user_id)
      return if user.blank?

      groups_for_ip(ip_address).each { |group| add_user_to_group(group, user) }
    end

    def self.backfill_ip!(ip_address:, group_ids:)
      groups = Group.where(id: group_ids)
      return if groups.blank?

      users_for_ip(ip_address).find_each do |user|
        groups.each { |group| add_user_to_group(group, user) }
      end
    end

    def self.groups_for_ip(ip_address)
      ip = normalize_ip(ip_address)
      return Group.none if ip.blank?

      # From direct enforcement rules
      group_ids =
        IpWatchlistEnforcement
          .enabled
          .where(ip_address: ip)
          .pluck(:group_id)

      # From IP group memberships → linked Discourse groups
      ip_group_ids =
        IpWatchlistGroupMembership
          .where(ip_address: ip)
          .pluck(:ip_watchlist_group_id)

      if ip_group_ids.present?
        group_ids |=
          IpWatchlistGroupDiscourseGroup
            .where(ip_watchlist_group_id: ip_group_ids)
            .pluck(:group_id)
      end

      Group.where(id: group_ids.uniq)
    end

    def self.users_for_ip(ip_address)
      ip = normalize_ip(ip_address)
      return User.none if ip.blank?

      user_ids =
        User.real.where("ip_address = :ip OR registration_ip_address = :ip", ip: ip).pluck(:id)

      if defined?(UserIpAddressHistory)
        user_ids |= UserIpAddressHistory.where(ip_address: ip).pluck(:user_id)
      end

      if defined?(UserAuthToken)
        user_ids |= UserAuthToken.where(client_ip: ip).pluck(:user_id)
      end

      User.real.where(id: user_ids.uniq)
    end

    def self.add_user_to_group(group, user)
      return if group.blank? || user.blank?
      return if group.users.exists?(id: user.id)

      group.add(user)
    rescue StandardError => e
      Rails.logger.warn(
        "[IpWatchlist] Failed to add user #{user.id} to group #{group.id}: #{e.message}",
      )
    end

    def self.normalize_ip(ip)
      return nil if ip.blank?
      IPAddr.new(ip.to_s).to_s
    rescue IPAddr::InvalidAddressError
      nil
    end

    private_class_method :add_user_to_group, :normalize_ip
  end
end
