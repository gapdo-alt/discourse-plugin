# frozen_string_literal: true

module SnowballPromoter
  module_function

  # Verification passed: join the verified group, bump the trust level, stamp
  # the verification time and clear any previous expiry marker.
  def promote!(user)
    group_name = SiteSetting.snowball_verified_group.to_s.strip
    if group_name.present?
      group = Group.find_by(name: group_name)
      if group
        add_to_group(group, user)
      else
        Rails.logger.warn("[discourse-snowball] 群组不存在: #{group_name}")
      end
    end

    target_tl = SiteSetting.snowball_trust_level.to_i
    if target_tl.positive? && user.trust_level < target_tl
      user.change_trust_level!(target_tl)
    end

    user.custom_fields["snowball_verified_at"] = Time.zone.now.iso8601
    user.custom_fields.delete("snowball_expired_at")
    user.save_custom_fields
  end

  # Verification expired: leave the verified group and move into the configured
  # expired group (when one is set).
  def expire!(user)
    verified_group_name = SiteSetting.snowball_verified_group.to_s.strip
    if verified_group_name.present?
      group = Group.find_by(name: verified_group_name)
      remove_from_group(group, user) if group
    end

    expired_group_name = SiteSetting.snowball_expired_group.to_s.strip
    if expired_group_name.present?
      group = Group.find_by(name: expired_group_name)
      if group
        add_to_group(group, user)
      else
        Rails.logger.warn("[discourse-snowball] 过期群组不存在: #{expired_group_name}")
      end
    end

    user.custom_fields["snowball_expired_at"] = Time.zone.now.iso8601
    user.save_custom_fields
  end

  def expired?(user)
    user.custom_fields["snowball_expired_at"].present? || expired_by_time?(user)
  end

  def verified_at(user)
    raw = user.custom_fields["snowball_verified_at"]
    return nil if raw.blank?

    Time.zone.parse(raw.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  # nil when the validity setting is 0 (never expires)
  def expires_at(user)
    days = SiteSetting.snowball_validity_days.to_i
    return nil if days <= 0

    at = verified_at(user)
    at && (at + days.days)
  end

  def expired_by_time?(user)
    at = expires_at(user)
    at.present? && at <= Time.zone.now
  end

  def add_to_group(group, user)
    return if group.users.exists?(id: user.id)

    group.add(user)
  rescue StandardError => e
    Rails.logger.warn("[discourse-snowball] 加入群组失败 #{group.id}/#{user.id}: #{e.message}")
  end

  def remove_from_group(group, user)
    return unless group.users.exists?(id: user.id)

    group.remove(user)
  rescue StandardError => e
    Rails.logger.warn("[discourse-snowball] 移出群组失败 #{group.id}/#{user.id}: #{e.message}")
  end
end
