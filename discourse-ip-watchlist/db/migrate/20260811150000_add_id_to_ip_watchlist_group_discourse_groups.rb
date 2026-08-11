# frozen_string_literal: true

class AddIdToIpWatchlistGroupDiscourseGroups < ActiveRecord::Migration[7.0]
  def up
    # Join table was created without a primary key; ActiveRecord needs one
    # for destroy / find_or_create_by on the join model.
    return if column_exists?(:ip_watchlist_group_discourse_groups, :id)

    execute <<~SQL
      ALTER TABLE ip_watchlist_group_discourse_groups
      ADD COLUMN id BIGSERIAL PRIMARY KEY
    SQL
  end

  def down
    remove_column :ip_watchlist_group_discourse_groups, :id if column_exists?(:ip_watchlist_group_discourse_groups, :id)
  end
end
