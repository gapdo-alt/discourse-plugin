# frozen_string_literal: true

class CreateIpWatchlistTables < ActiveRecord::Migration[7.0]
  def change
    create_table :ip_watchlist_entries do |t|
      t.inet :ip_address, null: false
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

    add_index :ip_watchlist_entries, :ip_address, unique: true
    add_index :ip_watchlist_entries, :last_seen_at
    add_index :ip_watchlist_entries, :reason

    create_table :ip_watchlist_enforcements do |t|
      t.inet :ip_address, null: false
      t.integer :group_id, null: false
      t.boolean :enabled, null: false, default: true
      t.integer :created_by_id
      t.timestamps
    end

    add_index :ip_watchlist_enforcements, %i[ip_address group_id], unique: true
    add_index :ip_watchlist_enforcements, :group_id
    add_index :ip_watchlist_enforcements, :enabled
  end
end
