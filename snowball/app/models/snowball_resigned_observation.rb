# frozen_string_literal: true

# Probe employee ids that users reported as "resigned".  Each vote lowers the
# chance of that id (and its +/-1000 neighbourhood) being drawn again.
class SnowballResignedObservation < ActiveRecord::Base
  self.table_name = "snowball_resigned_observations"

  VOTE_FACTOR = 0.95
  DEFAULT_RADIUS = 1000

  validates :employee_id, presence: true, uniqueness: true

  def self.record_vote!(employee_id)
    id = SnowballSeed.normalize_employee_id(employee_id)
    return if id.blank?

    observation = find_or_initialize_by(employee_id: id)
    votes = observation.resigned_votes.to_i + 1
    observation.resigned_votes = votes
    observation.probe_weight = VOTE_FACTOR**votes
    observation.range_radius = DEFAULT_RADIUS
    observation.save!
    observation
  end

  def self.import!(rows)
    imported = 0
    transaction do
      rows.each do |row|
        id = SnowballSeed.normalize_employee_id(row["employee_id"] || row[:employee_id])
        next if id.blank?

        observation = find_or_initialize_by(employee_id: id)
        votes = (row["resigned_votes"] || row[:resigned_votes] || 1).to_i
        observation.resigned_votes = votes
        weight = row["probe_weight"] || row[:probe_weight]
        observation.probe_weight = weight.present? ? weight.to_f : VOTE_FACTOR**votes
        observation.range_radius = (row["range_radius"] || row[:range_radius] || DEFAULT_RADIUS).to_i
        observation.save!
        imported += 1
      end
    end
    imported
  end
end
