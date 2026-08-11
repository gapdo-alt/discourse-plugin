# frozen_string_literal: true

class CreateIpWatchlistGroups < ActiveRecord::Migration[7.2]
  def up
    create_table :ip_watchlist_groups, if_not_exists: true do |t|
      t.string :name, null: false
      t.integer :created_by_id
      t.timestamps
    end

    add_index :ip_watchlist_groups, :name, unique: true, if_not_exists: true

    create_table :ip_watchlist_group_memberships, if_not_exists: true do |t|
      t.column :ip_address, :inet, null: false
      t.integer :ip_watchlist_group_id, null: false
      t.integer :created_by_id
      t.timestamps
    end

    add_index :ip_watchlist_group_memberships,
              %i[ip_watchlist_group_id ip_address],
              unique: true,
              name: "idx_ip_wl_group_memberships_unique",
              if_not_exists: true
    add_index :ip_watchlist_group_memberships, :ip_address, if_not_exists: true

    create_table :ip_watchlist_group_discourse_groups, if_not_exists: true do |t|
      t.integer :ip_watchlist_group_id, null: false
      t.integer :group_id, null: false
    end

    add_index :ip_watchlist_group_discourse_groups,
              %i[ip_watchlist_group_id group_id],
              unique: true,
              name: "idx_ip_wl_group_discourse_groups_unique",
              if_not_exists: true
  end

  def down
    drop_table :ip_watchlist_group_discourse_groups, if_exists: true
    drop_table :ip_watchlist_group_memberships, if_exists: true
    drop_table :ip_watchlist_groups, if_exists: true
  end
end
