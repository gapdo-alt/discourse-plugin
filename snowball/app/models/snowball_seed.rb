# frozen_string_literal: true

# One row per employee in the verification seed library.  The data is imported
# by an administrator (admin page → JSON upload); nothing is bundled with the
# plugin.
class SnowballSeed < ActiveRecord::Base
  self.table_name = "snowball_seeds"

  ACTIVE = "active"

  validates :employee_id, presence: true, uniqueness: true
  validates :surname, presence: true

  scope :usable, -> { where(status: ACTIVE, in_active_pool: true).where("confidence > 0") }

  def self.import!(rows)
    imported = 0
    now = Time.zone.now

    transaction do
      rows.each do |row|
        employee_id = normalize_employee_id(row["employee_id"] || row[:employee_id])
        surname = (row["surname"] || row[:surname]).to_s.strip
        next if employee_id.blank? || surname.blank?

        seed = find_or_initialize_by(employee_id: employee_id)
        seed.surname = surname
        seed.confidence = (row["confidence"] || row[:confidence] || 100).to_i
        seed.status = (row["status"] || row[:status] || ACTIVE).to_s
        seed.resigned_signals = (row["resigned_signals"] || row[:resigned_signals] || 0).to_i
        pool = row.key?("in_active_pool") ? row["in_active_pool"] : row[:in_active_pool]
        seed.in_active_pool = pool.nil? ? true : ActiveModel::Type::Boolean.new.cast(pool)
        added = row["added_at"] || row[:added_at]
        seed.added_at = added.to_i if added.present?
        seed.save!
        imported += 1
      end
    end

    imported
  end

  def self.normalize_employee_id(value)
    digits = value.to_s.strip
    return nil if digits.blank?

    digits.rjust(8, "0")
  end
end
