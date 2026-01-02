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

