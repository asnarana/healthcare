# raw ingestion log model
# stores raw json responses from apis temporarily (7-30 days retention)
# used for debugging and reprocessing failed data
# automatically cleaned up after retention period
class RawIngestionLog < ApplicationRecord
  self.table_name = 'raw_ingestion_logs'

  validates :source_name, presence: true
  validates :raw_json, presence: true
  validates :status, inclusion: { in: %w[pending processed failed] }

  # scope to find old records for cleanup
  scope :older_than, ->(days) { where('ingested_at < ?', days.days.ago) }
  scope :by_source, ->(source) { where(source_name: source) }
  scope :pending, -> { where(status: 'pending') }
  scope :processed, -> { where(status: 'processed') }
  scope :failed, -> { where(status: 'failed') }

  # mark as processed after successful upsert
  def mark_processed!
    update!(status: 'processed', processed_at: Time.current)
  end

  # mark as failed if processing error occurs
  def mark_failed!(error_message)
    update!(status: 'failed', error_message: error_message.truncate(4000))
  end
end

