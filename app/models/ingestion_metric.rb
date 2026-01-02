# ingestion metric model
# tracks ingestion job health and performance for prometheus monitoring
# used to monitor data ingestion pipeline health
class IngestionMetric < ApplicationRecord
  self.table_name = 'ingestion_metrics'

  validates :source_name, presence: true
  validates :job_run_at, presence: true
  validates :status, presence: true, inclusion: { in: %w[success failed partial] }

  # Query helper: get recent metrics for a source
  def self.recent_for_source(source_name, hours = 24)
    where(source_name: source_name)
      .where('job_run_at >= ?', hours.hours.ago)
      .order(job_run_at: :desc)
  end
end

