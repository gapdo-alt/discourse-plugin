# frozen_string_literal: true

class CreateSnowballLocalTables < ActiveRecord::Migration[7.2]
  def up
    create_table :snowball_seeds, if_not_exists: true do |t|
      t.string :employee_id, null: false
      t.string :surname, null: false
      t.integer :confidence, null: false, default: 100
      t.string :status, null: false, default: "active"
      t.integer :resigned_signals, null: false, default: 0
      t.boolean :in_active_pool, null: false, default: true
      t.bigint :added_at
      t.timestamps
    end
    add_index :snowball_seeds, :employee_id, unique: true, if_not_exists: true
    add_index :snowball_seeds, :in_active_pool, if_not_exists: true

    create_table :snowball_observations, if_not_exists: true do |t|
      t.string :employee_id, null: false
      t.jsonb :votes, null: false, default: {}
      t.integer :total, null: false, default: 0
      t.timestamps
    end
    add_index :snowball_observations, :employee_id, unique: true, if_not_exists: true

    create_table :snowball_resigned_observations, if_not_exists: true do |t|
      t.string :employee_id, null: false
      t.integer :resigned_votes, null: false, default: 0
      t.float :probe_weight, null: false, default: 1.0
      t.integer :range_radius, null: false, default: 1000
      t.timestamps
    end
    add_index :snowball_resigned_observations, :employee_id, unique: true, if_not_exists: true

    create_table :snowball_challenges, if_not_exists: true do |t|
      t.string :challenge_id, null: false
      t.integer :user_id, null: false
      t.jsonb :employee_ids, null: false, default: []
      t.datetime :expires_at, null: false
      t.datetime :completed_at
      t.boolean :passed
      t.timestamps
    end
    add_index :snowball_challenges, :challenge_id, unique: true, if_not_exists: true
    add_index :snowball_challenges, :user_id, if_not_exists: true
  end

  def down
    drop_table :snowball_challenges, if_exists: true
    drop_table :snowball_resigned_observations, if_exists: true
    drop_table :snowball_observations, if_exists: true
    drop_table :snowball_seeds, if_exists: true
  end
end
