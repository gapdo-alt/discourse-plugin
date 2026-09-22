# frozen_string_literal: true

class SnowballController < ::ApplicationController
  requires_login

  before_action :ensure_enabled

  # Renders the Ember app shell (app/views/snowball/index.html.erb is empty;
  # ApplicationController's `layout :set_layout` supplies the application or
  # crawler layout) so that GET /snowball can be opened directly.
  def index
  end

  # Starting a quiz is free -- an attempt is only consumed on submit (see
  # #verify).  We still refuse early here so the user finds out before
  # answering a whole quiz.
  def challenge
    blocked_reason = SnowballLimits.blocked_reason(current_user.id)
    return render_limit_error(blocked_reason) if blocked_reason

    res =
      SnowballApi.challenge(
        username: current_user.username,
        client_ip: request.remote_ip,
        cookies: cookie_header,
      )

    if res.set_cookie.present?
      response.headers["Set-Cookie"] = res.set_cookie
    end

    data = parse_body(res.body)

    render json: with_remaining(data), status: res.status
  rescue SnowballApi::Error => e
    render_json_error(e.message, status: e.status)
  end

  def verify
    blocked_reason = SnowballLimits.blocked_reason(current_user.id)
    return render_limit_error(blocked_reason) if blocked_reason

    body = parse_request_body
    challenge_id = body["challenge_id"]
    answers = normalize_answers(body["answers"])

    return render_json_error("缺少 challenge_id", status: 400) if challenge_id.blank?
    return render_json_error("answers 必须是非空数组", status: 400) if answers.blank?

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
    passed = res.status == 200 && data["passed"]

    # Submitting answers is what consumes one attempt.
    SnowballVerificationAttempt.record!(user_id: current_user.id, passed: passed)

    if passed
      SnowballPromoter.promote!(current_user)
      data["discourse_promoted"] = true
    else
      data["discourse_promoted"] = false
    end

    # The upstream API answers a failed verification (and an expired challenge)
    # with a 4xx plus a user-facing `message`.  That is a normal outcome, not a
    # transport error -- passing the 4xx through makes the client throw and
    # hide the message, so answer 200 and let the result screen render it.
    status = res.status >= 500 ? res.status : 200
    render json: with_remaining(data), status: status
  rescue SnowballApi::Error => e
    render_json_error(e.message, status: e.status)
  end

  def status
    # Lazy expiry: move the user out of the verified group as soon as the
    # deadline has passed, without waiting for the daily sweep job.
    if SnowballPromoter.expired_by_time?(current_user) &&
         current_user.custom_fields["snowball_expired_at"].blank?
      SnowballPromoter.expire!(current_user)
      current_user.reload
    end

    upstream_verified = SnowballPromoter.verified_on_snowball?(current_user.username)
    expired = SnowballPromoter.expired?(current_user)
    local_verified = current_user.custom_fields["snowball_verified_at"].present? && !expired

    # Backfill: verified upstream but never promoted locally (and not expired).
    if upstream_verified && !local_verified && !expired
      SnowballPromoter.promote!(current_user)
      current_user.reload
      local_verified = true
    end

    render json: {
             username: current_user.username,
             verified: local_verified,
             snowball_verified: upstream_verified,
             discourse_verified: local_verified,
             expired: expired,
             verified_at: current_user.custom_fields["snowball_verified_at"],
             expires_at: SnowballPromoter.expires_at(current_user)&.iso8601,
             remaining_attempts: SnowballLimits.remaining(current_user.id),
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

  def render_limit_error(reason)
    limit = SnowballLimits.limit_for(reason)
    render json: {
             error: I18n.t("snowball.errors.#{reason}", limit: limit),
             error_type: "snowball_#{reason}",
             limit: limit,
             remaining_attempts: SnowballLimits.remaining(current_user.id),
           },
           status: 429
  end

  def with_remaining(data)
    data.merge("remaining_attempts" => SnowballLimits.remaining(current_user.id))
  end

  def parse_body(body)
    JSON.parse(body)
  rescue JSON::ParserError
    { "error" => body }
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

  # Discourse's `ajax()` helper form-encodes its payload, so an array of
  # answers arrives as answers[0][...]=... which Rails parses back into a Hash
  # keyed by "0", "1", ... .  JSON clients send a real Array.  Accept both.
  def normalize_answers(raw)
    case raw
    when Array
      raw
    when Hash
      # keep the natural order of the "0", "1", ... keys
      raw.sort_by { |key, _| key.to_i }.map { |_, value| value }
    end
  end
end
