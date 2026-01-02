# delphi hospital capacity ingestion job
# background job that fetches hospital capacity data from delphi api
# runs daily (scheduled via sidekiq-cron)
# implements idempotent upserts to prevent duplicate data
class DelphiHospitalIngestionJob < ApplicationJob
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

  def perform(collection_start = nil, collection_end = nil)
    start_time = Time.current
    source_name = 'delphi_hospital'
    
    # Default to last 7 days if no dates provided
    if collection_start.nil? || collection_end.nil?
      collection_end = Date.today.strftime('%Y%m%d')
      collection_start = 7.days.ago.to_date.strftime('%Y%m%d')
    end

    begin
      # ========================================================================
      # STEP 1: Fetch data from Delphi Hospital Capacity API
      # ========================================================================
      # API endpoint: https://api.delphi.cmu.edu/epidata/covid_hosp_facility/
      # Note: This requires hospital_pks parameter - for demo, we'll fetch all
      # In production, you'd maintain a list of hospital_pks to monitor
      # ========================================================================
      url = "https://api.delphi.cmu.edu/epidata/covid_hosp_facility/?collection_weeks=#{collection_start}-#{collection_end}"
      response = HTTParty.get(url, timeout: 60)
      
      unless response.success?
        raise "API request failed with status #{response.code}"
      end

      data = JSON.parse(response.body)
      
      if data['result'] != 1 || data['epidata'].blank?
        Rails.logger.warn "No hospital data returned for period #{collection_start}-#{collection_end}"
        return
      end

      # ========================================================================
      # STEP 2: Process and upsert data
      # ========================================================================
      records_processed = 0
      records_inserted = 0
      records_updated = 0

      data['epidata'].each do |api_record|
        begin
          existing = HospitalCapacityDailyRollup.find_by(
            hospital_pk: api_record['hospital_pk'],
            collection_date: Date.parse(api_record['collection_date'])
          )

          if existing
            records_updated += 1
          else
            records_inserted += 1
          end

          HospitalCapacityDailyRollup.upsert_from_api_data(api_record)
          records_processed += 1
        rescue => e
          Rails.logger.error "Error processing hospital record: #{e.message}"
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

      Rails.logger.info "Hospital ingestion completed: #{records_processed} records processed in #{duration.round(2)}s"

    rescue => e
      Rails.logger.error "Hospital ingestion failed: #{e.message}"
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

