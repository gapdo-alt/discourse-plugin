# frozen_string_literal: true

class IpWatchlistGroup < ActiveRecord::Base
  self.table_name = "ip_watchlist_groups"

  has_many :memberships,
           class_name: "IpWatchlistGroupMembership",
           foreign_key: :ip_watchlist_group_id,
           dependent: :destroy

  has_many :discourse_group_links,
           class_name: "IpWatchlistGroupDiscourseGroup",
           foreign_key: :ip_watchlist_group_id,
           dependent: :destroy

  has_many :discourse_groups, through: :discourse_group_links, source: :group

  belongs_to :created_by, class_name: "User", optional: true

  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
end
