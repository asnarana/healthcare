# openaq ingestion job
# background job that fetches air quality data from openaq v3 api
# runs hourly (scheduled via sidekiq-cron)
# focuses on pm2.5 and o3 measurements as per requirements
# requires OPENAQ_API_KEY environment variable
class OpenAqIngestionJob < ApplicationJob
  queue_as :ingestion

  METRICS = Prometheus::Client.registry
  INGESTION_DURATION = METRICS.histogram(
    :ingestion_duration_seconds,
    docstring: 'Duration of ingestion job in seconds',
    labels: [:source]
  )
  INGESTION_RECORDS = METRICS.counter(
    :ingestion_records_total,
    docstring: 'Total records processed by ingestion job',
    labels: [:source, :status]
  )
  INGESTION_ERRORS = METRICS.counter(
    :ingestion_errors_total,
    docstring: 'Total ingestion errors',
    labels: [:source]
  )

  def perform(location_id = nil, zip_code = nil, latitude = nil, longitude = nil, radius_km = 10)
    start_time = Time.current
    source_name = 'openaq'
    
    # Check for API key
    api_key = ENV['OPENAQ_API_KEY']
    if api_key.blank?
      Rails.logger.warn "OpenAQ API key not set, skipping ingestion"
      return
    end

    begin
      # ========================================================================
      # STEP 1: Fetch data from OpenAQ v3 API
      # ========================================================================
      # API endpoint: https://api.openaq.org/v3/locations/{location_id}/latest
      # Or search by coordinates/ZIP
      # Focus on PM2.5 and O3 parameters
      # ========================================================================
      if location_id.present?
        # Fetch specific location
        url = "https://api.openaq.org/v3/locations/#{location_id}/latest"
      elsif latitude.present? && longitude.present?
        # Search by coordinates with radius (in meters)
        radius_m = (radius_km * 1000).to_i
        url = "https://api.openaq.org/v3/locations?coordinates=#{latitude},#{longitude}&radius=#{radius_m}&limit=10&parameters_id=2,8"
      elsif zip_code.present?
        # For demo, we'll use a default location if ZIP not mapped
        # In production, you'd maintain a ZIP -> location_id mapping or use geocoding
        url = "https://api.openaq.org/v3/locations?limit=10&parameters_id=2,8&countries_id=840" # US country code
      else
        # Default: fetch recent measurements for US
        url = "https://api.openaq.org/v3/locations?limit=10&parameters_id=2,8&countries_id=840" # US country code
      end

      headers = {
        'X-API-Key' => api_key,
        'Accept' => 'application/json'
      }

      response = HTTParty.get(url, headers: headers, timeout: 30)
      
      unless response.success?
        raise "API request failed with status #{response.code}: #{response.body}"
      end

      data = JSON.parse(response.body)
      
      if data['results'].blank?
        Rails.logger.warn "No OpenAQ data returned"
        return
      end

      # ========================================================================
      # STEP 2: Process and upsert data
      # ========================================================================
      records_processed = 0
      records_inserted = 0
      records_updated = 0

      # OpenAQ v3 returns locations with measurements
      locations = data['results'] || [data]
      
      locations.each do |location_data|
        # Get latest measurements for this location
        location_id = location_data['id'] || location_data['locationId']
        measurements = location_data['parameters'] || []
        
        # Create a combined record with PM2.5 and O3
        combined_measurement = {
          'location_id' => location_id,
          'locationId' => location_id,
          'coordinates' => {
            'latitude' => location_data['coordinates']&.dig('latitude'),
            'longitude' => location_data['coordinates']&.dig('longitude')
          },
          'date' => {
            'utc' => Time.current.iso8601
          },
          'measurements' => measurements.map do |param|
            {
              'parameter' => param['parameter']&.downcase,
              'value' => param['lastValue'],
              'unit' => param['unit']
            }
          end
        }

        begin
          # Derive ZIP from coordinates if not provided (simplified - in production use geocoding)
          derived_zip = zip_code || location_data['zip_code']
          
          existing = OpenAqHourlyRollup.find_by(
            location_id: location_id,
            measurement_date: Date.today,
            measurement_hour: Time.current.hour
          )

          if existing
            records_updated += 1
          else
            records_inserted += 1
          end

          OpenAqHourlyRollup.upsert_from_api_data(combined_measurement, derived_zip)
          records_processed += 1
        rescue => e
          Rails.logger.error "Error processing OpenAQ record: #{e.message}"
          INGESTION_ERRORS.increment(labels: { source: source_name })
        end
      end

      # ========================================================================
      # STEP 3: Record metrics
      # ========================================================================
      duration = Time.current - start_time
      INGESTION_DURATION.observe(duration, labels: { source: source_name })
      INGESTION_RECORDS.increment(by: records_processed, labels: { source: source_name, status: 'success' })

      IngestionMetric.create!(
        source_name: source_name,
        job_run_at: start_time,
        status: 'success',
        records_processed: records_processed,
        records_inserted: records_inserted,
        records_updated: records_updated,
        duration_ms: (duration * 1000).to_i
      )

      Rails.logger.info "OpenAQ ingestion completed: #{records_processed} records processed in #{duration.round(2)}s"

    rescue => e
      Rails.logger.error "OpenAQ ingestion failed: #{e.message}"
      INGESTION_ERRORS.increment(labels: { source: source_name })
      INGESTION_RECORDS.increment(labels: { source: source_name, status: 'failed' })

      IngestionMetric.create!(
        source_name: source_name,
        job_run_at: start_time,
        status: 'failed',
        records_processed: 0,
        error_message: e.message.truncate(4000),
        duration_ms: ((Time.current - start_time) * 1000).to_i
      )

      raise
    end
  end
end

