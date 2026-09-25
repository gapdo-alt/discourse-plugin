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
#
# All five questions are drawn from one aligned BLOCK_SIZE block of employee
# ids, so they share their leading digits and only differ in the last three --
# which makes them much easier to look up in the staff directory.
module SnowballVerifier
  CONFIDENCE_PENALTY = 3
  # Employee ids are 6 digit numbers zero padded to 8 characters, so the
  # documented probe range "00600000-00900000" is 600_000..900_000 -- reading
  # it as 6_000_000 would generate ids that no longer look like staff numbers.
  PROBE_RANGE = (600_000..900_000)
  # Questions share everything above the last `block_size` digits (a setting):
  # with 1000, 00612345 and 00612890 are in the same block, 00612345 and
  # 00622345 are not.
  DEFAULT_BLOCK_SIZE = 1000
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

  # ── configuration (admin → settings → plugins) ─────────────────────────
  def seed_questions
    SiteSetting.snowball_seed_questions.to_i.clamp(0, 9)
  end

  def probe_questions
    SiteSetting.snowball_probe_questions.to_i.clamp(0, 9)
  end

  def pass_threshold
    SiteSetting.snowball_pass_threshold.to_i.clamp(0, 9)
  end

  def block_size
    size = SiteSetting.snowball_block_size.to_i
    size.positive? ? size : DEFAULT_BLOCK_SIZE
  end

  def challenge!(user)
    if seed_questions + probe_questions <= 0
      raise Error.new("题目数量配置为 0（种子题 + 探测题），无法出题", status: 503)
    end

    block, seed_ids = pick_block_and_seeds
    if seed_ids.size < seed_questions
      raise Error.new("种子库为空或可用种子不足，请先在后台导入种子数据", status: 503)
    end

    probe_range =
      block ? (block * block_size..((block * block_size) + block_size - 1)) : PROBE_RANGE
    probe_ids = pick_probe_ids(probe_range)

    if probe_ids.size < probe_questions
      raise Error.new("可用探测工号不足，请调小区块粒度或检查种子库", status: 503)
    end

    # Ascending order: all ids come from one block, so a sorted list reads like
    # the staff directory and is much easier to look up.
    employee_ids = (seed_ids + probe_ids).sort
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

    passed = seed_correct >= pass_threshold
    challenge.update!(completed_at: Time.zone.now, passed: passed)

    payload = {
      "passed" => passed,
      "pass_threshold" => pass_threshold,
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

  # Picks one aligned block of ids that holds enough usable seeds and returns
  # [block_prefix, seed_ids].  With no seed questions configured the block is
  # chosen at random inside the probe range, purely to keep the questions
  # clustered.  Falls back to a global draw when the library is too sparse to
  # cluster (e.g. only a handful of seeds imported).
  def pick_block_and_seeds
    if seed_questions.zero?
      blocks = [(PROBE_RANGE.size / block_size), 1].max
      return [(PROBE_RANGE.first / block_size) + rand(blocks), []]
    end

    seeds_by_block =
      SnowballSeed.usable.pluck(:employee_id).group_by do |employee_id|
        employee_id.to_i / block_size
      end

    candidates =
      seeds_by_block.select do |block, ids|
        ids.size >= seed_questions && (block * block_size) >= PROBE_RANGE.first
      end

    if candidates.empty?
      return [nil, SnowballSeed.usable.order("RANDOM()").limit(seed_questions).pluck(:employee_id)]
    end

    block, ids = candidates.to_a.sample
    [block, ids.sample(seed_questions)]
  end

  def pick_probe_ids(range)
    seed_ids = SnowballSeed.pluck(:employee_id).map(&:to_i).to_set
    affected =
      probe_weights.select { |id, _weight| range.cover?(id) && !seed_ids.include?(id) }

    in_range_seeds = seed_ids.count { |id| range.cover?(id) }
    unaffected_count = range.size - in_range_seeds - affected.size
    affected_total = affected.values.sum
    total = (unaffected_count * 1.0) + affected_total
    return [] if total <= 0

    picked = []
    attempts = 0
    while picked.size < probe_questions && attempts < 200
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

      candidate ||= random_unaffected_id(seed_ids, affected, range)
      next if candidate.nil? || picked.include?(candidate)

      picked << candidate
    end

    picked.map { |id| format("%08d", id) }
  end

  def random_unaffected_id(seed_ids, affected, range)
    50.times do
      id = rand(range)
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
      # Fold Latin answers to upper case so "l" and "L" land in the same vote
      # bucket (the client does the same; CJK is unaffected by upcase).
      SnowballObservation.record_vote!(employee_id, answer[:surname].to_s.strip.upcase)
    end
  end
end
