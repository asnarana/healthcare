# openaq hourly rollup model
# represents hourly aggregated air quality data from openaq api
# this is the canonical storage for pm2.5 and o3 measurements
# focus on pm2.5 and o3 as per requirements
class OpenAqHourlyRollup < ApplicationRecord
  self.table_name = 'openaq_hourly_rollups'

  validates :location_id, presence: true
  validates :measurement_date, presence: true
  validates :measurement_hour, presence: true, inclusion: { in: 0..23 }
  validates :location_id, uniqueness: { scope: [:measurement_date, :measurement_hour] }

  # upsert method - idempotent data insertion
  def self.upsert_from_api_data(api_data, zip_code = nil)
    location_id = api_data['location_id'] || api_data['locationId']
    measurement_date = Date.parse(api_data['date']['utc'].split('T').first)
    measurement_hour = Time.parse(api_data['date']['utc']).hour

    # Extract PM2.5 and O3 values from measurements array
    pm25_data = api_data['measurements']&.find { |m| m['parameter'] == 'pm25' }
    o3_data = api_data['measurements']&.find { |m| m['parameter'] == 'o3' }

    record = find_or_initialize_by(
      location_id: location_id,
      measurement_date: measurement_date,
      measurement_hour: measurement_hour
    )

    record.assign_attributes(
      latitude: api_data['coordinates']['latitude'],
      longitude: api_data['coordinates']['longitude'],
      zip_code: zip_code || api_data['zip_code'],
      pm25_value: pm25_data&.dig('value'),
      pm25_unit: pm25_data&.dig('unit'),
      o3_value: o3_data&.dig('value'),
      o3_unit: o3_data&.dig('unit'),
      last_updated: Time.current
    )

    record.save!
    record
  rescue ActiveRecord::RecordNotUnique
    record = find_by(
      location_id: location_id,
      measurement_date: measurement_date,
      measurement_hour: measurement_hour
    )
    record&.update(
      latitude: api_data['coordinates']['latitude'],
      longitude: api_data['coordinates']['longitude'],
      zip_code: zip_code || api_data['zip_code'],
      pm25_value: pm25_data&.dig('value'),
      pm25_unit: pm25_data&.dig('unit'),
      o3_value: o3_data&.dig('value'),
      o3_unit: o3_data&.dig('unit'),
      last_updated: Time.current
    )
    record
  end

  # Query helper: get air quality data for a ZIP code and date range
  def self.for_zip_and_date_range(zip_code, start_date, end_date)
    where(zip_code: zip_code)
      .where('measurement_date >= ? AND measurement_date <= ?', start_date, end_date)
      .order(:measurement_date, :measurement_hour)
  end

  # Query helper: get air quality data by coordinates (within radius) and date range
  # radius is in kilometers (default 10km)
  def self.for_coordinates_and_date_range(latitude, longitude, start_date, end_date, radius_km = 10)
    # simple distance calculation using haversine formula
    # in production, you might want to use a spatial database extension
    # for now, we'll use a bounding box approximation
    lat_range = radius_km / 111.0  # roughly 111 km per degree latitude
    lon_range = radius_km / (111.0 * Math.cos(latitude * Math::PI / 180.0))
    
    where('latitude BETWEEN ? AND ?', latitude - lat_range, latitude + lat_range)
      .where('longitude BETWEEN ? AND ?', longitude - lon_range, longitude + lon_range)
      .where('measurement_date >= ? AND measurement_date <= ?', start_date, end_date)
      .order(:measurement_date, :measurement_hour)
  end
end

