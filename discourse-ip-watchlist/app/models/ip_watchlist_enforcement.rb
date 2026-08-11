# frozen_string_literal: true

class IpWatchlistEnforcement < ActiveRecord::Base
  self.table_name = "ip_watchlist_enforcements"

  belongs_to :group
  belongs_to :created_by, class_name: "User", optional: true

  validates :ip_address, presence: true
  validates :group_id, presence: true, uniqueness: { scope: :ip_address }
  validates :enabled, inclusion: { in: [true, false] }

  before_validation :normalize_ip_address

  scope :enabled, -> { where(enabled: true) }
  scope :for_ip, ->(ip) { where(ip_address: IpWatchlistEntry.normalize_ip(ip)) }

  def self.normalize_ip(ip)
    IpWatchlistEntry.normalize_ip(ip)
  end

  private

  def normalize_ip_address
    self.ip_address = self.class.normalize_ip(ip_address)
  end
end
