# Sidekiq configuration
# This initializer sets up Sidekiq for background job processing

require 'sidekiq'
require 'sidekiq-cron'

# Configure Redis connection
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://redis:6379/0') }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://redis:6379/0') }
end

# Schedule cron jobs for data ingestion
# These jobs run periodically to fetch data from external APIs
Sidekiq::Cron::Job.load_from_hash(
  # Delphi FluView - fetch weekly flu data (runs every Monday)
  'delphi_fluview_ingestion' => {
    'cron' => '0 2 * * 1', # Every Monday at 2 AM
    'class' => 'DelphiFluviewIngestionJob',
    'queue' => 'ingestion'
  },
  # Delphi Hospital Capacity - fetch daily hospital data
  'delphi_hospital_ingestion' => {
    'cron' => '0 3 * * *', # Every day at 3 AM
    'class' => 'DelphiHospitalIngestionJob',
    'queue' => 'ingestion'
  },
  # openFDA Drug Enforcement - fetch daily enforcement data
  'fda_enforcement_ingestion' => {
    'cron' => '0 4 * * *', # Every day at 4 AM
    'class' => 'FdaEnforcementIngestionJob',
    'queue' => 'ingestion'
  },
  # OpenAQ Air Quality - fetch hourly air quality data
  'openaq_ingestion' => {
    'cron' => '0 * * * *', # Every hour
    'class' => 'OpenAqIngestionJob',
    'queue' => 'ingestion'
  }
)

