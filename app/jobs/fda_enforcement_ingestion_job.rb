# fda enforcement ingestion job
# background job that fetches drug enforcement data from openfda api
# runs daily (scheduled via sidekiq-cron)
# implements idempotent upserts to prevent duplicate data
class FdaEnforcementIngestionJob < ApplicationJob
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

  def perform(report_start = nil, report_end = nil)
    start_time = Time.current
    source_name = 'fda_enforcement'
    
    # Default to last 7 days if no dates provided
    if report_start.nil? || report_end.nil?
      report_end = Date.today.strftime('%Y%m%d')
      report_start = 7.days.ago.to_date.strftime('%Y%m%d')
    end

    begin
      # ========================================================================
      # STEP 1: Fetch data from openFDA Drug Enforcement API
      # ========================================================================
      # API endpoint: https://api.fda.gov/drug/enforcement.json
      # Parameters: search=report_date:[YYYYMMDD+TO+YYYYMMDD]&limit=100
      # Note: openFDA has rate limits, so we fetch in batches
      # ========================================================================
      url = "https://api.fda.gov/drug/enforcement.json?search=report_date:[#{report_start}+TO+#{report_end}]&limit=100"
      response = HTTParty.get(url, timeout: 30)
      
      unless response.success?
        raise "API request failed with status #{response.code}"
      end

      data = JSON.parse(response.body)
      
      if data['results'].blank?
        Rails.logger.warn "No FDA enforcement data returned for period #{report_start}-#{report_end}"
        return
      end

      # ========================================================================
      # STEP 2: Process and upsert data
      # ========================================================================
      records_processed = 0
      records_inserted = 0
      records_updated = 0

      data['results'].each do |api_record|
        begin
          existing = FdaEnforcementDailyRollup.find_by(recall_number: api_record['recall_number'])

          if existing
            records_updated += 1
          else
            records_inserted += 1
          end

          FdaEnforcementDailyRollup.upsert_from_api_data(api_record)
          records_processed += 1
        rescue => e
          Rails.logger.error "Error processing FDA record: #{e.message}"
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

      Rails.logger.info "FDA enforcement ingestion completed: #{records_processed} records processed in #{duration.round(2)}s"

    rescue => e
      Rails.logger.error "FDA enforcement ingestion failed: #{e.message}"
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

