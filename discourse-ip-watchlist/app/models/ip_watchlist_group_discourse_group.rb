# frozen_string_literal: true

class IpWatchlistGroupDiscourseGroup < ActiveRecord::Base
  self.table_name = "ip_watchlist_group_discourse_groups"

  belongs_to :ip_watchlist_group
  belongs_to :group
end
