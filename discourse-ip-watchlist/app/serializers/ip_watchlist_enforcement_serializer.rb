# frozen_string_literal: true

class IpWatchlistEnforcementSerializer < ApplicationSerializer
  attributes :id, :ip_address, :group_id, :group_name, :enabled, :created_by_id, :created_at, :updated_at

  def ip_address
    object.ip_address.to_s
  end

  def group_name
    object.group&.name
  end
end
