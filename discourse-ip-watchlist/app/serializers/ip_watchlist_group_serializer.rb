# frozen_string_literal: true

class IpWatchlistGroupSerializer < ApplicationSerializer
  attributes :id, :name, :discourse_group_ids, :discourse_group_names, :membership_count, :member_ips, :created_at

  def discourse_group_ids
    object.discourse_group_links.pluck(:group_id)
  end

  def discourse_group_names
    object.discourse_groups.pluck(:name)
  end

  def membership_count
    object.memberships.count
  end

  def member_ips
    object.memberships.order(:created_at).limit(200).pluck(:ip_address).map(&:to_s)
  end
end
