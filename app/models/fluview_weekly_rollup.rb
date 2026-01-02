# fluview weekly rollup model
# represents weekly aggregated flu data from delphi fluview api
# this is the canonical (main) storage for flu data
class FluviewWeeklyRollup < ApplicationRecord
  self.table_name = 'fluview_weekly_rollups'

  # Validations
  validates :region_code, presence: true
  validates :epiweek_start, presence: true
  validates :epiweek_end, presence: true
  validates :year, presence: true
  validates :week_number, presence: true, uniqueness: { scope: [:region_code, :year] }

  # upsert method - idempotent data insertion
  # this method ensures we can safely re-run ingestion jobs without duplicates
  # uses oracle's merge statement for efficient upserts
  def self.upsert_from_api_data(api_data, region_code = 'nat')
    # Parse epidemiological week from API response
    epiweek = api_data['epiweek'].to_i
    year = epiweek / 100
    week_num = epiweek % 100
    
    # Calculate week start/end dates (simplified - actual calculation is more complex)
    week_start = Date.new(year, 1, 1) + (week_num - 1).weeks
    week_end = week_start + 6.days

    # Upsert using find_or_initialize_by + save (Rails way)
    # Oracle's unique constraint will prevent duplicates
    record = find_or_initialize_by(
      region_code: region_code,
      year: year,
      week_number: week_num
    )

    record.assign_attributes(
      epiweek_start: week_start,
      epiweek_end: week_end,
      wili: api_data['wili'],
      ili: api_data['ili'],
      num_providers: api_data['num_providers'],
      num_patients: api_data['num_patients'],
      num_ili: api_data['num_ili'],
      last_updated: Time.current
    )

    record.save!
    record
  rescue ActiveRecord::RecordNotUnique
    # If unique constraint violation, try to find and update
    record = find_by(region_code: region_code, year: year, week_number: week_num)
    record&.update(
      wili: api_data['wili'],
      ili: api_data['ili'],
      num_providers: api_data['num_providers'],
      num_patients: api_data['num_patients'],
      num_ili: api_data['num_ili'],
      last_updated: Time.current
    )
    record
  end

  # Query helper: get flu data for a date range
  def self.for_date_range(start_date, end_date, region_code = 'nat')
    where(region_code: region_code)
      .where('epiweek_start >= ? AND epiweek_end <= ?', start_date, end_date)
      .order(:epiweek_start)
  end
end

