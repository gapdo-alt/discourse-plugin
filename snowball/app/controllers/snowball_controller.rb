# frozen_string_literal: true

class SnowballController < ::ApplicationController
  requires_login

  before_action :ensure_enabled

  def challenge
    res =
      SnowballApi.challenge(
        username: current_user.username,
        client_ip: request.remote_ip,
        cookies: cookie_header,
      )

    if res.set_cookie.present?
      response.headers["Set-Cookie"] = res.set_cookie
    end

    render json: parse_body(res.body), status: res.status
  rescue SnowballApi::Error => e
    render_json_error(e.message, status: e.status)
  end

  def verify
    body = parse_request_body
    challenge_id = body["challenge_id"]
    answers = body["answers"]

    if challenge_id.blank? || !answers.is_a?(Array)
      return render_json_error("缺少 challenge_id 或 answers", status: 400)
    end

    normalized =
      answers.map do |a|
        h = a.is_a?(Hash) ? a.stringify_keys : {}
        if ActiveModel::Type::Boolean.new.cast(h["resigned"])
          { employee_id: h["employee_id"], resigned: true }
        else
          { employee_id: h["employee_id"], surname: h["surname"].to_s }
        end
      end

    res =
      SnowballApi.verify(
        challenge_id: challenge_id,
        username: current_user.username,
        answers: normalized,
        client_ip: request.remote_ip,
        cookies: cookie_header,
      )

    data = parse_body(res.body)

    if res.status == 200 && data["passed"]
      SnowballPromoter.promote!(current_user)
      data["discourse_promoted"] = true
    else
      data["discourse_promoted"] = false
    end

    render json: data, status: res.status
  rescue SnowballApi::Error => e
    render_json_error(e.message, status: e.status)
  end

  def status
    verified = SnowballPromoter.verified_on_snowball?(current_user.username)
    local_verified = current_user.custom_fields["snowball_verified_at"].present?

    if verified && !local_verified
      SnowballPromoter.promote!(current_user)
      local_verified = true
    end

    render json: {
      username: current_user.username,
      verified: verified || local_verified,
      snowball_verified: verified,
      discourse_verified: local_verified,
    }
  rescue SnowballApi::Error => e
    render_json_error(e.message, status: e.status)
  end

  private

  def ensure_enabled
    raise Discourse::InvalidAccess unless SiteSetting.snowball_enabled
  end

  def cookie_header
    request.headers["Cookie"]
  end

  def parse_body(body)
    JSON.parse(body)
  rescue JSON::ParserError
    { error: body }
  end

  def parse_request_body
    if request.content_type&.include?("application/json")
      JSON.parse(request.raw_post)
    else
      params.to_unsafe_h
    end
  rescue JSON::ParserError
    {}
  end
end
