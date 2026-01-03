source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '>= 3.2.0', '< 3.3.0'

# Rails framework
gem 'rails', '~> 7.1.0'

# Database adapter for Oracle
gem 'activerecord-oracle_enhanced-adapter', '~> 7.0'

# Background job processing
gem 'sidekiq', '~> 7.0'
gem 'sidekiq-cron', '~> 1.10' # For scheduled jobs

# Web server
gem 'puma', '~> 6.0'

# Hotwire (Turbo + Stimulus)
gem 'turbo-rails'
gem 'stimulus-rails'

# Tailwind CSS
gem 'tailwindcss-rails'

# HTTP client for API calls
gem 'httparty', '~> 0.21'

# JSON parsing
gem 'json'

# Prometheus metrics
gem 'prometheus-client', '~> 2.1'
gem 'prometheus-client-mmap', '~> 0.28'

# Environment variables
gem 'dotenv-rails'

# Boot speed optimization
gem 'bootsnap', '>= 1.4.4', require: false

group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
end

group :development do
  gem 'web-console', '>= 4.1.0'
  gem 'listen', '~> 3.3'
end
