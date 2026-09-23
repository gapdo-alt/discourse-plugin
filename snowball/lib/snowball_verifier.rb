# frozen_string_literal: true

# Local implementation of the Snowball verification rules.  Replaces the
# previous remote API call: the seed library is imported by an administrator
# (admin page → JSON upload), everything else stays in this plugin.
#
# Rules (per the upstream API documentation):
#   * 5 questions: 3 seed questions + 2 probe questions
#   * a seed question counts as correct when the submitted surname matches
#   * 2 of the 3 seed questions correct => passed
#   * a wrong seed answer lowers that seed's confidence by 3
#   * probe answered "resigned"      => that id and its +/-1000 neighbourhood
#                                       get 5% less likely per vote
#   * probe answered with a surname  => anchor enters the observation library,
#                                       its +/-1000 neighbourhood gets 5% more
#                                       likely per anchor, capped at 2.5x
module SnowballVerifier
  SEED_QUESTIONS = 3
  PROBE_QUESTIONS = 2
  PASS_THRESHOLD = 2
  CONFIDENCE_PENALTY = 3
  # Employee ids are 6 digit numbers zero padded to 8 characters, so the
  # documented probe range "00600000-00900000" is 600_000..900_000 -- reading
  # it as 6_000_000 would generate ids that no longer look like staff numbers.
  PROBE_RANGE = (600_000..900_000)
  DEFAULT_RADIUS = 1000
  OBSERVATION_FACTOR = 1.05
  MAX_PROBE_WEIGHT = 2.5
  CHALLENGE_TTL = 5.minutes

  class Error < StandardError
    attr_reader :status

    def initialize(message, status: 400)
      super(message)
      @status = status
    end
  end

  module_function

  def challenge!(user)
    seed_ids = pick_seed_ids
    if seed_ids.size < SEED_QUESTIONS
      raise Error.new("种子库为空或可用种子不足，请先在后台导入种子数据", status: 503)
    end

    employee_ids = (seed_ids + pick_probe_ids).shuffle
    challenge =
      SnowballChallenge.create!(
        challenge_id: SecureRandom.uuid,
        user_id: user.id,
        employee_ids: employee_ids,
        expires_at: CHALLENGE_TTL.from_now,
      )

    {
      "challenge_id" => challenge.challenge_id,
      "expires_at" => (challenge.expires_at.to_f * 1000).to_i,
      "employee_ids" => challenge.employee_ids,
    }
  end

  def verify!(user:, challenge_id:, answers:)
    challenge = SnowballChallenge.find_by(challenge_id: challenge_id.to_s, user_id: user.id)
    raise Error.new("挑战不存在或已失效") if challenge.nil?
    raise Error.new("该挑战已完成，请重新开始") if challenge.completed?
    raise Error.new("挑战已过期，请重新开始") if challenge.expired?

    seed_ids = SnowballSeed.where(employee_id: challenge.employee_ids).pluck(:employee_id).to_set
    answers_by_id = {}
    answers.each { |answer| answers_by_id[answer[:employee_id].to_s] = answer }

    seed_total = 0
    seed_correct = 0

    challenge.employee_ids.each do |employee_id|
      answer = answers_by_id[employee_id]

      if seed_ids.include?(employee_id)
        seed = SnowballSeed.find_by(employee_id: employee_id)
        next if seed.nil?

        seed_total += 1
        correct =
          answer.present? && !answer[:resigned] &&
            normalize_surname(answer[:surname]) == normalize_surname(seed.surname)
        seed_correct += 1 if correct
        apply_seed_result(seed, correct)
      else
        apply_probe_result(employee_id, answer)
      end
    end

    passed = seed_correct >= PASS_THRESHOLD
    challenge.update!(completed_at: Time.zone.now, passed: passed)

    payload = {
      "passed" => passed,
      "pass_threshold" => PASS_THRESHOLD,
      "message" =>
        (
          if passed
            I18n.t("snowball.result_pass")
          else
            I18n.t("snowball.result_fail")
          end
        ),
    }

    # Do not leak which questions were right (that would hand out the answers),
    # except to staff who may need it for support.
    if user.staff?
      payload["seed_total"] = seed_total
      payload["seed_correct"] = seed_correct
    end

    payload
  end

  def normalize_surname(value)
    value.to_s.strip.downcase
  end

  def pick_seed_ids
    SnowballSeed.usable.order("RANDOM()").limit(SEED_QUESTIONS).pluck(:employee_id)
  end

  def pick_probe_ids
    seed_ids = SnowballSeed.pluck(:employee_id).map(&:to_i).to_set
    affected = probe_weights.reject { |id, _weight| seed_ids.include?(id) }

    in_range_seeds = seed_ids.count { |id| PROBE_RANGE.cover?(id) }
    unaffected_count = PROBE_RANGE.size - in_range_seeds - affected.size
    affected_total = affected.values.sum
    total = (unaffected_count * 1.0) + affected_total
    return [] if total <= 0

    picked = []
    attempts = 0
    while picked.size < PROBE_QUESTIONS && attempts < 200
      attempts += 1
      candidate = nil
      roll = rand * total

      if affected_total.positive? && roll < affected_total
        acc = 0.0
        affected.each do |id, weight|
          acc += weight
          if roll < acc
            candidate = id
            break
          end
        end
      end

      candidate ||= random_unaffected_id(seed_ids, affected)
      next if candidate.nil? || picked.include?(candidate)

      picked << candidate
    end

    picked.map { |id| format("%08d", id) }
  end

  def random_unaffected_id(seed_ids, affected)
    50.times do
      id = rand(PROBE_RANGE)
      next if seed_ids.include?(id) || affected.key?(id)

      return id
    end
    nil
  end

  # { employee_id => draw weight } for every probe id touched by an anchor
  def probe_weights
    weights = Hash.new(1.0)

    SnowballResignedObservation.find_each do |observation|
      anchor = observation.employee_id.to_i
      radius = observation.range_radius.to_i
      ((anchor - radius)..(anchor + radius)).each do |id|
        weights[id] *= observation.probe_weight if PROBE_RANGE.cover?(id)
      end
    end

    observed = Hash.new(0)
    SnowballObservation.find_each do |observation|
      anchor = observation.employee_id.to_i
      ((anchor - DEFAULT_RADIUS)..(anchor + DEFAULT_RADIUS)).each do |id|
        observed[id] += 1 if PROBE_RANGE.cover?(id)
      end
    end
    observed.each do |id, count|
      weights[id] *= [OBSERVATION_FACTOR**count, MAX_PROBE_WEIGHT].min
    end

    weights
  end

  def apply_seed_result(seed, correct)
    return if correct

    confidence = [seed.confidence.to_i - CONFIDENCE_PENALTY, 0].max
    seed.update_columns(
      confidence: confidence,
      in_active_pool: confidence.positive?,
      updated_at: Time.zone.now,
    )
  end

  def apply_probe_result(employee_id, answer)
    return if answer.blank?

    if answer[:resigned]
      SnowballResignedObservation.record_vote!(employee_id)
    elsif answer[:surname].present?
      SnowballObservation.record_vote!(employee_id, answer[:surname])
    end
  end
end
