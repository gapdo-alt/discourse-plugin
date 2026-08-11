# frozen_string_literal: true

class CreateIpWatchlistGroups < ActiveRecord::Migration[7.0]
  def change
    create_table :ip_watchlist_groups do |t|
      t.string :name, null: false
      t.integer :created_by_id
      t.timestamps
    end

    add_index :ip_watchlist_groups, :name, unique: true

    create_table :ip_watchlist_group_memberships do |t|
      t.inet :ip_address, null: false
      t.integer :ip_watchlist_group_id, null: false
      t.integer :created_by_id
      t.timestamps
    end

    add_index :ip_watchlist_group_memberships,
              %i[ip_watchlist_group_id ip_address],
              unique: true,
              name: "idx_ip_wl_group_memberships_unique"
    add_index :ip_watchlist_group_memberships, :ip_address

    create_table :ip_watchlist_group_discourse_groups do |t|
      t.integer :ip_watchlist_group_id, null: false
      t.integer :group_id, null: false
    end

    add_index :ip_watchlist_group_discourse_groups,
              %i[ip_watchlist_group_id group_id],
              unique: true,
              name: "idx_ip_wl_group_discourse_groups_unique"
  end
end
