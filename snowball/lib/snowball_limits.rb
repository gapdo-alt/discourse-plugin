# frozen_string_literal: true

# Daily / weekly verification attempt limits.
#
# One attempt = one submitted answer (starting a quiz is free).  A limit of 0
# means "unlimited".  Windows are calendar based in the site time zone
# (today / this week), which is what the UI wording ("今日 / 本周") implies.
module SnowballLimits
  module_function

  def daily_limit
    SiteSetting.snowball_daily_attempt_limit.to_i
  end

  def weekly_limit
    SiteSetting.snowball_weekly_attempt_limit.to_i
  end

  def daily_used(user_id)
    count_since(user_id, Time.zone.now.beginning_of_day)
  end

  def weekly_used(user_id)
    count_since(user_id, Time.zone.now.beginning_of_week)
  end

  # nil means unlimited for that window
  def remaining(user_id)
    {
      daily: daily_limit.positive? ? [daily_limit - daily_used(user_id), 0].max : nil,
      weekly: weekly_limit.positive? ? [weekly_limit - weekly_used(user_id), 0].max : nil,
      daily_limit: daily_limit,
      weekly_limit: weekly_limit,
    }
  end

  def blocked_reason(user_id)
    if daily_limit.positive? && daily_used(user_id) >= daily_limit
      "daily_limit"
    elsif weekly_limit.positive? && weekly_used(user_id) >= weekly_limit
      "weekly_limit"
    end
  end

  def allowed?(user_id)
    blocked_reason(user_id).nil?
  end

  def limit_for(reason)
    reason == "daily_limit" ? daily_limit : weekly_limit
  end

  def count_since(user_id, since)
    SnowballVerificationAttempt.where(user_id: user_id).where("created_at >= ?", since).count
  end
end
