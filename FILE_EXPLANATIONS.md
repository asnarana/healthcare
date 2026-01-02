# File Explanations - Simple Guide

## What Each File Does

### Docker & Configuration Files

**docker-compose.yml**
- tells docker how to run all 8 services (oracle, redis, rails, sidekiq, fastapi, ollama, prometheus, grafana)
- defines which ports to expose, environment variables, and how services connect to each other
- when you run `docker-compose up`, it reads this file and starts everything

**Dockerfile.rails**
- instructions for building the rails application container
- installs ruby, oracle client libraries, and all dependencies
- used by both rails and sidekiq services

**env.example / .env**
- environment variables (api keys, database passwords, etc)
- copy env.example to .env and add your openaq api key
- .env is ignored by git (keeps secrets safe)

**config/database.yml**
- tells rails how to connect to oracle database
- connection string, username, password, host, port

**config/routes.rb**
- defines all the urls in the application
- `/dashboard/:zip` shows dashboard for a zip code
- `/chat` handles ai chat questions
- `/metrics` exposes prometheus metrics

**config/initializers/sidekiq.rb**
- configures sidekiq (background job processor)
- sets up scheduled jobs (when to run each ingestion job)
- fluview runs weekly, others run daily/hourly

### Database Files

**db/migrate/001_create_health_data_tables.rb**
- creates all 5 database tables when you run `rails db:migrate`
- table 1: fluview_weekly_rollups (flu data)
- table 2: hospital_capacity_daily_rollups (hospital beds)
- table 3: fda_enforcement_daily_rollups (drug recalls)
- table 4: openaq_hourly_rollups (air quality)
- table 5: ingestion_metrics (job performance tracking)

### Models (app/models/)

**fluview_weekly_rollup.rb**
- represents flu data in the database
- has method `upsert_from_api_data` that saves data (insert or update if exists)
- prevents duplicate data

**hospital_capacity_daily_rollup.rb**
- represents hospital capacity data
- has upsert method to save data without duplicates

**fda_enforcement_daily_rollup.rb**
- represents fda recall data
- has upsert method

**openaq_hourly_rollup.rb**
- represents air quality data
- has upsert method

**ingestion_metric.rb**
- represents job performance metrics
- tracks success/failure, how long jobs took, etc

### Jobs (app/jobs/)

**delphi_fluview_ingestion_job.rb**
- background job that fetches flu data from delphi api
- runs weekly (monday 2am)
- step 1: calls api to get data
- step 2: saves each record to database
- step 3: records metrics about the job

**delphi_hospital_ingestion_job.rb**
- fetches hospital capacity data from delphi api
- runs daily (3am)
- same 3-step process

**fda_enforcement_ingestion_job.rb**
- fetches drug recall data from openfda api
- runs daily (4am)
- same 3-step process

**openaq_ingestion_job.rb**
- fetches air quality data from openaq api
- runs hourly
- requires openaq api key from .env file
- same 3-step process

### Controllers (app/controllers/)

**dashboard_controller.rb**
- handles dashboard pages
- `index` action: shows home page with zip code form
- `show` action: shows dashboard for a zip code
  - validates zip code (must be 5 digits)
  - queries database for air quality, hospital, flu, fda data
  - prepares data for charts and map
  - gets coordinates for map center

**chat_controller.rb**
- handles ai chat questions
- receives question from frontend
- forwards to fastapi service
- returns ai's answer

**metrics_controller.rb**
- exposes prometheus metrics endpoint
- prometheus scrapes this to collect metrics

### Views (app/views/)

**layouts/application.html.erb**
- main html template for all pages
- includes navigation, flash messages, footer
- loads maplibre (for maps) and chart.js (for charts)

**dashboard/index.html.erb**
- home page with form to enter zip code
- shows information about data sources

**dashboard/show.html.erb**
- dashboard page for a zip code
- displays 4 charts (air quality, hospital, flu, fda)
- shows map with health facilities
- has chat interface at bottom

### FastAPI Service (fastapi_service/)

**main.py**
- fastapi web application
- `/health` endpoint: check if service is running
- `/chat` endpoint: receives questions, returns ai answers
- `/metrics` endpoint: prometheus metrics

**llm_service.py**
- handles ai chat logic
- uses langchain to create tools that query oracle database
- uses ollama (local ai) to generate answers
- has 4 tools: query_air_quality, query_hospital_capacity, query_flu_data, query_fda_enforcements

**requirements.txt**
- python packages needed (fastapi, langchain, ollama, etc)

**Dockerfile**
- instructions for building fastapi container
- installs python and dependencies

### Monitoring Files

**prometheus/prometheus.yml**
- configures prometheus
- tells it which services to scrape for metrics
- scrapes rails and fastapi every 15 seconds

**grafana/provisioning/datasources/prometheus.yml**
- tells grafana where to find prometheus
- auto-configures data source

**grafana/dashboards/ingestion-health.json**
- dashboard showing ingestion job performance
- charts for job duration, records processed, errors

**grafana/dashboards/llm-latency.json**
- dashboard showing llm query performance
- charts for query duration, query rate, errors

### Other Files

**README.md**
- overview of the project
- architecture explanation
- quick start guide

**SETUP.md**
- detailed setup instructions
- troubleshooting guide
- how to run jobs manually

**lib/tasks/cleanup.rake**
- rake tasks for maintenance
- `healthsignal:ingest_all` - run all ingestion jobs manually
- useful for testing

## Data Flow

1. **Ingestion**: sidekiq jobs run on schedule, fetch data from apis, save to oracle
2. **Display**: user enters zip code, dashboard queries oracle, shows charts and map
3. **Chat**: user asks question, rails forwards to fastapi, fastapi queries oracle with langchain, ollama generates answer
4. **Monitoring**: prometheus collects metrics, grafana displays dashboards

## Key Concepts

- **Upsert**: insert new record or update if it already exists (prevents duplicates)
- **Idempotent**: running the same job multiple times produces same result (safe to rerun)
- **Rollup**: aggregated data (daily/weekly) instead of raw individual records
- **Partitioning**: (removed for simplicity) would split tables by time for performance
- **Sidekiq**: background job processor (runs jobs asynchronously)
- **LangChain**: framework that lets ai use tools (like database queries)
- **Ollama**: local ai that runs on your computer (free, no api costs)

