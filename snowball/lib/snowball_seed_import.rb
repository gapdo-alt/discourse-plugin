# frozen_string_literal: true

# Import service for the admin JSON upload.  Accepts the upstream admin export
# shape
#
#   { "total": 228, "surname_stats": [...], "seeds": [ {employee_id, surname, ...} ] }
#
# a bare array of seeds, or the observation exports:
#
#   { "observations": [...] } / { "resigned_observations": [...] }
#
# Everything is optional; whatever is present gets merged in.
module SnowballSeedImport
  class Error < StandardError
  end

  module_function

  def call(payload)
    data = payload.is_a?(String) ? JSON.parse(payload) : payload
    raise Error, "JSON 顶层必须是对象或数组" unless data.is_a?(Array) || data.is_a?(Hash)

    seeds = data.is_a?(Array) ? data : (data["seeds"] || [])
    observations = data.is_a?(Hash) ? (data["observations"] || []) : []
    resigned = data.is_a?(Hash) ? (data["resigned_observations"] || []) : []

    if seeds.empty? && observations.empty? && resigned.empty?
      raise Error, "未找到 seeds / observations / resigned_observations 数据"
    end

    {
      seeds: SnowballSeed.import!(seeds),
      observations: SnowballObservation.import!(observations),
      resigned_observations: SnowballResignedObservation.import!(resigned),
    }
  rescue JSON::ParserError => e
    raise Error, "JSON 解析失败：#{e.message}"
  end

  def stats
    {
      seeds: SnowballSeed.count,
      usable_seeds: SnowballSeed.usable.count,
      observations: SnowballObservation.count,
      resigned_observations: SnowballResignedObservation.count,
      last_seed_at: SnowballSeed.maximum(:updated_at)&.iso8601,
    }
  end
end
