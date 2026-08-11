# frozen_string_literal: true

class AddIdToIpWatchlistGroupDiscourseGroups < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:ip_watchlist_group_discourse_groups)
    return if column_exists?(:ip_watchlist_group_discourse_groups, :id)

    # Older installs created this join table without a primary key.
    execute <<~SQL
      ALTER TABLE ip_watchlist_group_discourse_groups
      ADD COLUMN id BIGSERIAL PRIMARY KEY
    SQL
  end

  def down
    return unless table_exists?(:ip_watchlist_group_discourse_groups)
    return unless column_exists?(:ip_watchlist_group_discourse_groups, :id)

    remove_column :ip_watchlist_group_discourse_groups, :id
  end
end
