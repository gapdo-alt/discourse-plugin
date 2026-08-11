# frozen_string_literal: true

class IpWatchlistEntry < ActiveRecord::Base
  self.table_name = "ip_watchlist_entries"

  REASONS = %w[org_keyword hostname_keyword referrer manual].freeze

  belongs_to :created_by, class_name: "User", optional: true

  validates :ip_address, presence: true, uniqueness: true
  validates :reason, presence: true, inclusion: { in: REASONS }

  before_validation :normalize_ip_address

  def self.upsert_hit!(ip_address:, reason:, organization: nil, hostname: nil, referrer: nil)
    ip = normalize_ip(ip_address)
    return if ip.blank?

    entry = find_or_initialize_by(ip_address: ip)
    entry.reason = reason if entry.new_record? || entry.reason == "manual"
    entry.organization = organization if organization.present?
    entry.hostname = hostname if hostname.present?
    entry.referrer = referrer if referrer.present?
    entry.hit_count = entry.hit_count.to_i + 1
    entry.first_seen_at ||= Time.zone.now
    entry.last_seen_at = Time.zone.now
    entry.save!
    entry
  end

  def self.normalize_ip(ip)
    return nil if ip.blank?
    IPAddr.new(ip.to_s).to_s
  rescue IPAddr::InvalidAddressError
    nil
  end

  def related_user_count
    IpWatchlist::GroupAssigner.users_for_ip(ip_address).count
  end

  def sample_user_id
    IpWatchlist::GroupAssigner.users_for_ip(ip_address).limit(1).pick(:id)
  end

  private

  def normalize_ip_address
    self.ip_address = self.class.normalize_ip(ip_address)
  end
end

# == Schema Information
#
# Table name: ip_watchlist_entries
#
#  id              :bigint           not null, primary key
#  ip_address      :inet             not null
#  reason          :string           not null
#  organization    :string
#  hostname        :string
#  referrer        :text
#  hit_count       :integer          default(1), not null
#  first_seen_at   :datetime         not null
#  last_seen_at    :datetime         not null
#  created_by_id   :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
