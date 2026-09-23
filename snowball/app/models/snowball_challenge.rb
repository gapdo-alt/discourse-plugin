# frozen_string_literal: true

# A pending quiz handed to a user.  Challenges live entirely in the plugin now
# (nothing is stored upstream), which is also what makes the 5 minute expiry
# enforceable locally.
class SnowballChallenge < ActiveRecord::Base
  self.table_name = "snowball_challenges"

  belongs_to :user

  def expired?
    expires_at <= Time.zone.now
  end

  def completed?
    completed_at.present?
  end
end
