# frozen_string_literal: true

module SnowballPromoter
  module_function

  def promote!(user)
    group_name = SiteSetting.snowball_verified_group.to_s.strip
    if group_name.present?
      group = Group.find_by(name: group_name)
      if group
        group.add(user) unless group.users.include?(user)
      else
        Rails.logger.warn("[discourse-snowball] 群组不存在: #{group_name}")
      end
    end

    target_tl = SiteSetting.snowball_trust_level.to_i
    if target_tl.positive? && user.trust_level < target_tl
      user.change_trust_level!(target_tl)
    end

    user.custom_fields["snowball_verified_at"] = Time.zone.now.iso8601
    user.save_custom_fields
  end

  def verified_on_snowball?(username)
    res = SnowballApi.status(username: username)
    return false unless res.status == 200

    res.json["verified"] == true
  rescue SnowballApi::Error => e
    Rails.logger.warn("[discourse-snowball] status 查询失败: #{e.message}")
    false
  end
end
