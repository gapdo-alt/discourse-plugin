# frozen_string_literal: true

class CreateIpWatchlistTables < ActiveRecord::Migration[7.2]
  def up
    create_table :ip_watchlist_entries, if_not_exists: true do |t|
      t.column :ip_address, :inet, null: false
      t.string :reason, null: false
      t.string :organization
      t.string :hostname
      t.text :referrer
      t.integer :hit_count, null: false, default: 1
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.integer :created_by_id
      t.timestamps
    end

    add_index :ip_watchlist_entries, :ip_address, unique: true, if_not_exists: true
    add_index :ip_watchlist_entries, :last_seen_at, if_not_exists: true
    add_index :ip_watchlist_entries, :reason, if_not_exists: true

    create_table :ip_watchlist_enforcements, if_not_exists: true do |t|
      t.column :ip_address, :inet, null: false
      t.integer :group_id, null: false
      t.boolean :enabled, null: false, default: true
      t.integer :created_by_id
      t.timestamps
    end

    add_index :ip_watchlist_enforcements,
              %i[ip_address group_id],
              unique: true,
              if_not_exists: true
    add_index :ip_watchlist_enforcements, :group_id, if_not_exists: true
    add_index :ip_watchlist_enforcements, :enabled, if_not_exists: true
  end

  def down
    drop_table :ip_watchlist_enforcements, if_exists: true
    drop_table :ip_watchlist_entries, if_exists: true
  end
end
