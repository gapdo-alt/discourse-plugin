# frozen_string_literal: true

class IpWatchlistGroupMembership < ActiveRecord::Base
  self.table_name = "ip_watchlist_group_memberships"

  belongs_to :ip_watchlist_group
  belongs_to :created_by, class_name: "User", optional: true

  validates :ip_address, presence: true
  validates :ip_watchlist_group_id, presence: true, uniqueness: { scope: :ip_address }

  before_validation :normalize_ip_address

  private

  def normalize_ip_address
    return if ip_address.blank?
    self.ip_address = IPAddr.new(ip_address.to_s).to_s
  rescue IPAddr::InvalidAddressError
    # leave as-is for validation to catch
  end
end
