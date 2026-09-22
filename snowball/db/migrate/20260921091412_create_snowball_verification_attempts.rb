# frozen_string_literal: true

class CreateSnowballVerificationAttempts < ActiveRecord::Migration[7.2]
  def up
    create_table :snowball_verification_attempts, if_not_exists: true do |t|
      t.integer :user_id, null: false
      t.string :outcome, null: false, default: "started"
      t.timestamps
    end

    add_index :snowball_verification_attempts,
              %i[user_id created_at],
              name: "idx_snowball_attempts_user_created",
              if_not_exists: true
  end

  def down
    drop_table :snowball_verification_attempts, if_exists: true
  end
end
