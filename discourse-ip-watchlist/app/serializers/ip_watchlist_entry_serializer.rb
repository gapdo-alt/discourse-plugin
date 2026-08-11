# frozen_string_literal: true

class IpWatchlistEntrySerializer < ApplicationSerializer
  attributes :id,
             :ip_address,
             :reason,
             :organization,
             :hostname,
             :referrer,
             :hit_count,
             :first_seen_at,
             :last_seen_at,
             :created_by_id,
             :related_user_count,
             :sample_user_id,
             :same_ip_admin_url,
             :enforcement_group_ids

  def ip_address
    object.ip_address.to_s
  end

  def related_user_count
    object.related_user_count
  end

  def sample_user_id
    object.sample_user_id
  end

  def same_ip_admin_url
    "/admin/users/list/active?ip=#{CGI.escape(object.ip_address.to_s)}"
  end

  def enforcement_group_ids
    IpWatchlistEnforcement.where(ip_address: object.ip_address).pluck(:group_id)
  end
end
