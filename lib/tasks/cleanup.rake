# cleanup tasks
# rake tasks for maintaining the database

namespace :healthsignal do
  desc "Run all ingestion jobs manually"
  task ingest_all: :environment do
    puts "Running all ingestion jobs..."
    
    puts "1. Delphi FluView..."
    DelphiFluviewIngestionJob.perform_now
    
    puts "2. Delphi Hospital..."
    DelphiHospitalIngestionJob.perform_now
    
    puts "3. FDA Enforcement..."
    FdaEnforcementIngestionJob.perform_now
    
    puts "4. OpenAQ..."
    OpenAqIngestionJob.perform_now
    
    puts "All ingestion jobs completed!"
  end
end

# cleanup rake tasks
# tasks to clean up old data and maintain database health
namespace :cleanup do
  # task to clean up old raw ingestion logs (retention: 7-30 days)
  # keeps raw json for 7-30 days for debugging, then deletes
  # keeps failed records longer (30 days) for investigation
  desc "Clean up old raw ingestion logs (7 days for processed, 30 days for failed)"
  task raw_ingestion_logs: :environment do
    # delete processed records older than 7 days
    processed_cutoff = 7.days.ago
    processed_deleted = RawIngestionLog.processed.older_than(7).delete_all
    
    # delete failed records older than 30 days (keep longer for investigation)
    failed_cutoff = 30.days.ago
    failed_deleted = RawIngestionLog.failed.older_than(30).delete_all
    
    puts "Cleaned up #{processed_deleted} processed raw logs (older than 7 days)"
    puts "Cleaned up #{failed_deleted} failed raw logs (older than 30 days)"
    puts "Total deleted: #{processed_deleted + failed_deleted}"
  end

  # task to clean up old ingestion metrics (older than 90 days)
  desc "Clean up old ingestion metrics (older than 90 days)"
  task ingestion_metrics: :environment do
    cutoff_date = 90.days.ago
    
    deleted_count = IngestionMetric.where('job_run_at < ?', cutoff_date).delete_all
    
    puts "Cleaned up #{deleted_count} old ingestion metrics (older than #{cutoff_date})"
  end

  # task to clean up all old data
  desc "Clean up all old data"
  task all: :environment do
    Rake::Task['cleanup:raw_ingestion_logs'].invoke
    Rake::Task['cleanup:ingestion_metrics'].invoke
    puts "Cleanup complete!"
  end
end
