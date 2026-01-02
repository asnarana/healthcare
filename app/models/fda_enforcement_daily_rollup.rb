# fda enforcement daily rollup model
# represents daily aggregated drug enforcement data from openfda api
# this is the canonical storage for fda recall/enforcement data
class FdaEnforcementDailyRollup < ApplicationRecord
  self.table_name = 'fda_enforcement_daily_rollups'

  validates :recall_number, presence: true, uniqueness: true
  validates :report_date, presence: true

  # upsert method - idempotent data insertion
  def self.upsert_from_api_data(api_data)
    recall_number = api_data['recall_number'] || api_data['recall_number']
    report_date = Date.parse(api_data['report_date'])

    record = find_or_initialize_by(recall_number: recall_number)

    record.assign_attributes(
      report_date: report_date,
      product_description: api_data['product_description'],
      reason_for_recall: api_data['reason_for_recall'],
      classification: api_data['classification'],
      status: api_data['status'],
      state: api_data['state'],
      country: api_data['country'],
      last_updated: Time.current
    )

    record.save!
    record
  rescue ActiveRecord::RecordNotUnique
    record = find_by(recall_number: recall_number)
    record&.update(
      report_date: report_date,
      product_description: api_data['product_description'],
      reason_for_recall: api_data['reason_for_recall'],
      classification: api_data['classification'],
      status: api_data['status'],
      state: api_data['state'],
      country: api_data['country'],
      last_updated: Time.current
    )
    record
  end

  # Query helper: get enforcement data for a date range
  def self.for_date_range(start_date, end_date)
    where('report_date >= ? AND report_date <= ?', start_date, end_date)
      .order(:report_date)
  end
end

