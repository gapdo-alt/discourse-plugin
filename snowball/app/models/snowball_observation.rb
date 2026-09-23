# frozen_string_literal: true

# Probe (non-seed) employee ids that collected at least one surname vote.  Each
# anchor raises the chance for its whole +/-1000 neighbourhood of being drawn
# again, which is how uncertain ids get resolved over time.
class SnowballObservation < ActiveRecord::Base
  self.table_name = "snowball_observations"

  validates :employee_id, presence: true, uniqueness: true

  def self.record_vote!(employee_id, surname)
    id = SnowballSeed.normalize_employee_id(employee_id)
    surname = surname.to_s.strip
    return if id.blank? || surname.blank?

    observation = find_or_initialize_by(employee_id: id)
    votes = (observation.votes || {}).dup
    votes[surname] = votes[surname].to_i + 1
    observation.votes = votes
    observation.total = observation.total.to_i + 1
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
        observation.votes = (row["votes"] || row[:votes] || {})
        observation.total = (row["total"] || row[:total] || 0).to_i
        observation.save!
        imported += 1
      end
    end
    imported
  end
end
