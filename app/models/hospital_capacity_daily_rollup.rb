# hospital capacity daily rollup model
# represents daily aggregated hospital capacity data from delphi api
# this is the canonical storage for hospital capacity metrics
class HospitalCapacityDailyRollup < ApplicationRecord
  self.table_name = 'hospital_capacity_daily_rollups'

  validates :hospital_pk, presence: true
  validates :collection_date, presence: true
  validates :hospital_pk, uniqueness: { scope: :collection_date }

  # upsert method - idempotent data insertion
  def self.upsert_from_api_data(api_data)
    hospital_pk = api_data['hospital_pk'] || api_data['hospital_pk']
    collection_date = Date.parse(api_data['collection_date'])

    record = find_or_initialize_by(
      hospital_pk: hospital_pk,
      collection_date: collection_date
    )

    record.assign_attributes(
      state: api_data['state'],
      zip_code: api_data['zip_code'],
      total_beds: api_data['total_beds'],
      occupied_beds: api_data['occupied_beds'],
      icu_beds: api_data['icu_beds'],
      icu_occupied: api_data['icu_occupied'],
      covid_patients: api_data['covid_patients'],
      last_updated: Time.current
    )

    record.save!
    record
  rescue ActiveRecord::RecordNotUnique
    record = find_by(hospital_pk: hospital_pk, collection_date: collection_date)
    record&.update(
      state: api_data['state'],
      zip_code: api_data['zip_code'],
      total_beds: api_data['total_beds'],
      occupied_beds: api_data['occupied_beds'],
      icu_beds: api_data['icu_beds'],
      icu_occupied: api_data['icu_occupied'],
      covid_patients: api_data['covid_patients'],
      last_updated: Time.current
    )
    record
  end

  # Query helper: get hospital data for a ZIP code and date range
  def self.for_zip_and_date_range(zip_code, start_date, end_date)
    where(zip_code: zip_code)
      .where('collection_date >= ? AND collection_date <= ?', start_date, end_date)
      .order(:collection_date)
  end

  # Query helper: get hospital data by coordinates (within radius) and date range
  # finds nearby zip codes from openaq data, then filters hospitals by those zip codes
  # radius is in kilometers (default 10km)
  def self.for_coordinates_and_date_range(latitude, longitude, start_date, end_date, radius_km = 10)
    # find zip codes near the coordinates using openaq data (which has lat/lon)
    # simple distance calculation using bounding box
    lat_range = radius_km / 111.0  # roughly 111 km per degree latitude
    lon_range = radius_km / (111.0 * Math.cos(latitude * Math::PI / 180.0))
    
    nearby_zips = OpenAqHourlyRollup
      .where('latitude BETWEEN ? AND ?', latitude - lat_range, latitude + lat_range)
      .where('longitude BETWEEN ? AND ?', longitude - lon_range, longitude + lon_range)
      .where.not(zip_code: nil)
      .select(:zip_code)
      .distinct
      .pluck(:zip_code)
      .compact
    
    # if no nearby zips found, return empty result
    return where('1=0') if nearby_zips.empty?
    
    # filter hospitals by nearby zip codes
    where(zip_code: nearby_zips)
      .where('collection_date >= ? AND collection_date <= ?', start_date, end_date)
      .order(:collection_date)
  end
end

