# frozen_string_literal: true

# One row per submitted verification (i.e. the user actually answered a
# challenge).  Used to enforce the daily/weekly attempt limits: merely starting
# a quiz does not count, only submitting answers does.
class SnowballVerificationAttempt < ActiveRecord::Base
  self.table_name = "snowball_verification_attempts"

  PASSED = "passed"
  FAILED = "failed"

  belongs_to :user

  def self.record!(user_id:, passed:)
    create!(user_id: user_id, outcome: passed ? PASSED : FAILED)
  end
end
