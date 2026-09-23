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
    return render_verified_error if already_verified?

    blocked_reason = SnowballLimits.blocked_reason(current_user.id)
    return render_limit_error(blocked_reason) if blocked_reason

    data = SnowballVerifier.challenge!(current_user)
    render json: with_remaining(data)
  rescue SnowballVerifier::Error => e
    render_json_error(e.message, status: e.status)
  end

  def verify
    return render_verified_error if already_verified?

    blocked_reason = SnowballLimits.blocked_reason(current_user.id)
    return render_limit_error(blocked_reason) if blocked_reason

    body = parse_request_body
    challenge_id = body["challenge_id"]
    answers = normalize_answers(body["answers"])

    return render_json_error("缺少 challenge_id", status: 400) if challenge_id.blank?
    return render_json_error("answers 必须是非空数组", status: 400) if answers.blank?

    normalized = answers.map { |answer| normalize_answer(answer) }

    data =
      SnowballVerifier.verify!(
        user: current_user,
        challenge_id: challenge_id,
        answers: normalized,
      )

    passed = data["passed"] == true
    SnowballVerificationAttempt.record!(user_id: current_user.id, passed: passed)

    if passed
      SnowballPromoter.promote!(current_user)
      data["discourse_promoted"] = true
    else
      data["discourse_promoted"] = false
    end

    render json: with_remaining(data)
  rescue SnowballVerifier::Error => e
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

    expired = SnowballPromoter.expired?(current_user)
    verified = current_user.custom_fields["snowball_verified_at"].present? && !expired

    render json: {
             username: current_user.username,
             verified: verified,
             expired: expired,
             verified_at: current_user.custom_fields["snowball_verified_at"],
             expires_at: SnowballPromoter.expires_at(current_user)&.iso8601,
             remaining_attempts: SnowballLimits.remaining(current_user.id),
           }
  end

  private

  def ensure_enabled
    raise Discourse::InvalidAccess unless SiteSetting.snowball_enabled
  end

  # Already verified and still inside the validity window -> nothing to do.
  def already_verified?
    current_user.custom_fields["snowball_verified_at"].present? &&
      !SnowballPromoter.expired?(current_user)
  end

  def render_verified_error
    render json: {
             error: I18n.t("snowball.errors.already_verified"),
             error_type: "snowball_already_verified",
           },
           status: 409
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
      raw.sort_by { |key, _| key.to_i }.map { |_, value| value }
    end
  end

  def normalize_answer(answer)
    hash = answer.is_a?(Hash) ? answer.stringify_keys : {}
    employee_id = hash["employee_id"].to_s

    if ActiveModel::Type::Boolean.new.cast(hash["resigned"])
      { employee_id: employee_id, resigned: true }
    else
      { employee_id: employee_id, surname: hash["surname"].to_s }
    end
  end
end
