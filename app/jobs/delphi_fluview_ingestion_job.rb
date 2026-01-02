# this job fetches flu data from the delphi fluview api
# it runs automatically every week (monday at 2am) via sidekiq-cron
# it saves the data to the oracle database
class DelphiFluviewIngestionJob < ApplicationJob
  queue_as :ingestion  # put this job in the 'ingestion' queue

  # set up prometheus metrics so we can monitor how well this job is running
  METRICS = Prometheus::Client.registry

  # track how long each job takes to run
  INGESTION_DURATION = METRICS.histogram(
    :ingestion_duration_seconds,
    docstring: 'Duration of ingestion job in seconds',
    labels: [:source]
  )

  # track how many records we process
  INGESTION_RECORDS = METRICS.counter(
    :ingestion_records_total,
    docstring: 'Total records processed by ingestion job',
    labels: [:source, :status]
  )

  # track how many errors we get
  INGESTION_ERRORS = METRICS.counter(
    :ingestion_errors_total,
    docstring: 'Total ingestion errors',
    labels: [:source]
  )

  # this is the main method that runs when the job executes
  def perform(epiweek_start = nil, epiweek_end = nil)
    start_time = Time.current  # remember when we started
    source_name = 'delphi_fluview'  # name of this data source
    
    # if no dates provided, default to last 4 weeks of data
    if epiweek_start.nil? || epiweek_end.nil?
      end_date = Date.today
      start_date = 4.weeks.ago.to_date
      epiweek_start = start_date.strftime('%Y%W')  # format as year+week (202401)
      epiweek_end = end_date.strftime('%Y%W')
    end

    begin
      # step 1: call the delphi api to get flu data
      # api endpoint: https://api.delphi.cmu.edu/epidata/fluview/
      # fetch national data first (always works), then fetch state data in batches
      # this ensures we have data even if some state requests fail
      
      # first fetch national data
      url = "https://api.delphi.cmu.edu/epidata/fluview/?regions=nat&epiweeks=#{epiweek_start}-#{epiweek_end}"
      response = HTTParty.get(url, timeout: 30)  # make http request, wait max 30 seconds
      
      # check if the api call was successful
      unless response.success?
        raise "API request failed with status #{response.code}"
      end

      data = JSON.parse(response.body)  # parse the json response
      
      # step 2: save each record to the database
      records_processed = 0  # count how many we process
      records_inserted = 0  # count how many are new
      records_updated = 0  # count how many we update

      # process national data
      if data['result'] == 1 && data['epidata'].present?
        data['epidata'].each do |api_record|
          begin
            region_code = 'nat'  # national data
            
            existing = FluviewWeeklyRollup.find_by(
              region_code: region_code,
              year: api_record['epiweek'].to_i / 100,
              week_number: api_record['epiweek'].to_i % 100
            )

            if existing
              records_updated += 1
            else
              records_inserted += 1
            end

            FluviewWeeklyRollup.upsert_from_api_data(api_record, region_code)
            records_processed += 1
          rescue => e
            Rails.logger.error "Error processing flu record: #{e.message}"
            INGESTION_ERRORS.increment(labels: { source: source_name })
          end
        end
      end
      
      # now fetch state data in batches (10 states at a time to avoid API limits)
      state_codes = %w[al ak az ar ca co ct de dc fl ga hi id il in ia ks ky la me md ma mi mn ms mo mt ne nv nh nj nm ny nc nd oh ok or pa ri sc sd tn tx ut vt va wa wv wi wy]
      state_codes.each_slice(10) do |state_batch|
        begin
          state_url = "https://api.delphi.cmu.edu/epidata/fluview/?regions=#{state_batch.join(',')}&epiweeks=#{epiweek_start}-#{epiweek_end}"
          state_response = HTTParty.get(state_url, timeout: 30)
          
          if state_response.success?
            state_data = JSON.parse(state_response.body)
            if state_data['result'] == 1 && state_data['epidata'].present?
              state_data['epidata'].each do |api_record|
                begin
                  region_code = api_record['region'] || state_batch.first
                  
                  existing = FluviewWeeklyRollup.find_by(
                    region_code: region_code,
                    year: api_record['epiweek'].to_i / 100,
                    week_number: api_record['epiweek'].to_i % 100
                  )

                  if existing
                    records_updated += 1
                  else
                    records_inserted += 1
                  end

                  FluviewWeeklyRollup.upsert_from_api_data(api_record, region_code)
                  records_processed += 1
                rescue => e
                  Rails.logger.error "Error processing state flu record: #{e.message}"
                  INGESTION_ERRORS.increment(labels: { source: source_name })
                end
              end
            end
          end
        rescue => e
          # if a batch fails, log but continue with other batches
          Rails.logger.warn "Error fetching state batch #{state_batch.join(',')}: #{e.message}"
        end
      end

      # step 3: record metrics so we can see how the job performed
      duration = Time.current - start_time
      INGESTION_DURATION.observe(duration, labels: { source: source_name })
      INGESTION_RECORDS.increment(by: records_processed, labels: { source: source_name, status: 'success' })

      # Store metric in database for Grafana
      IngestionMetric.create!(
        source_name: source_name,
        job_run_at: start_time,
        status: 'success',
        records_processed: records_processed,
        records_inserted: records_inserted,
        records_updated: records_updated,
        duration_ms: (duration * 1000).to_i
      )

      Rails.logger.info "FluView ingestion completed: #{records_processed} records processed in #{duration.round(2)}s"

    rescue => e
      # ========================================================================
      # ERROR HANDLING: Log error and record metrics
      # ========================================================================
      Rails.logger.error "FluView ingestion failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      INGESTION_ERRORS.increment(labels: { source: source_name })
      INGESTION_RECORDS.increment(labels: { source: source_name, status: 'failed' })

      # Store failed metric
      IngestionMetric.create!(
        source_name: source_name,
        job_run_at: start_time,
        status: 'failed',
        records_processed: 0,
        error_message: e.message.truncate(4000),
        duration_ms: ((Time.current - start_time) * 1000).to_i
      )

      # Re-raise to trigger Sidekiq retry
      raise
    end
  end
end

