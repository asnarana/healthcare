# Health Radar

A comprehensive health data monitoring dashboard built with Rails 7, Oracle Database, and LLM-powered chat. Monitor air quality, hospital capacity, flu activity, and FDA recalls for any location in the US.

## Architecture

### Stack
- **Rails 7** + Hotwire + Tailwind CSS + MapLibre
- **Sidekiq** + Redis for background job processing
- **Oracle Database Free** (gvenzl/oracle-free) with time-series optimized schema
- **FastAPI** microservice with LangChain + Ollama (local LLM)
- **Prometheus** + **Grafana** for monitoring

### Data Sources
1. **Delphi FluView** - Weekly influenza-like illness data (national + all 50 states)
2. **Delphi Hospital Capacity** - Daily hospital bed availability
3. **openFDA** - Drug enforcement and recall data
4. **OpenAQ** - Air quality measurements (PM2.5, O3)

## Features

### Location-Based Search
- **ZIP Code Search**: Enter a 5-digit ZIP code to view health data for that area
- **Coordinate Search**: Enter latitude/longitude to search within a 10km radius
- **Automatic Filtering**: OpenAQ and Hospital data automatically filter by location

### Interactive Dashboard
- **4 Data Visualizations**:
  - Air Quality (PM2.5, O3) - Line chart with daily averages
  - Hospital Capacity (Total/Occupied Beds) - Bar chart
  - Flu Activity (Weighted ILI %) - Line chart by region/state
  - FDA Recalls - Bar chart showing recalls per day

- **Time Range Selectors**: Independent dropdowns for each data source
  - Air Quality: 7, 14, 30, 60, 90, or 180 days
  - Hospital: 7, 14, 30, 60, 90, or 180 days
  - Flu: 4, 8, 12, 16, 24, or 52 weeks (with days shown)
  - FDA: 7, 14, 30, 60, 90, or 180 days

- **Region/State Filters**:
  - Flu Data: National, Auto-detect (from ZIP/coordinates), or any US state
  - FDA Recalls: All States (default) or filter by specific state

- **Interactive Map**: MapLibre map showing hospital locations and air quality stations

- **LLM-Powered Chat**: Ask questions about health data using natural language

## Quick Start

### Prerequisites
- Docker and Docker Compose
- OpenAQ API key (free at https://openaq.org/)

### Setup

1. **Clone and configure:**
   ```bash
   git clone https://github.com/asnarana/healthcare.git
   cd healthcare
   cp env.example .env
   # Edit .env and add your OPENAQ_API_KEY
   ```

2. **Start services:**
   ```bash
   docker-compose up -d
   ```

3. **Initialize database:**
   ```bash
   docker-compose exec rails bundle exec rails db:migrate
   ```

4. **Download Ollama model (first time only):**
   ```bash
   docker-compose exec ollama ollama pull llama2
   ```

5. **Access the application:**
   - Rails app: http://localhost:3000
   - Grafana: http://localhost:3001 (admin/admin)
   - Prometheus: http://localhost:9090
   - FastAPI: http://localhost:8000

## Data Pipeline

### Ingestion Flow
1. **Sidekiq Cron Jobs** run on schedule:
   - **Delphi FluView**: Weekly (Mondays 2 AM) - Fetches national + all 50 states
   - **Delphi Hospital**: Daily (3 AM) - Fetches hospital capacity data
   - **openFDA**: Daily (4 AM) - Fetches drug enforcement/recall data
   - **OpenAQ**: Hourly - Fetches PM2.5 and O3 measurements

2. **Data Processing (3-Step Pipeline):**
   - **Step 1: Fetch** - Raw JSON responses stored in `raw_ingestion_logs` table
   - **Step 2: Process** - Data extracted and aggregated into rollup tables (canonical storage)
   - **Step 3: Cleanup** - Raw JSON retained 7-30 days, then automatically deleted
   - Idempotent upserts prevent duplicates
   - Metrics recorded for monitoring

3. **Oracle Schema Design:**
   - **Time-Series Rollups**: Daily/weekly/hourly aggregates stored as canonical data
   - **Partitioning**: All rollup tables partitioned by time (daily/weekly intervals)
   - **Raw JSON Staging**: Temporary storage in `raw_ingestion_logs` (7-30 day retention)
   - **Unique Keys + Upserts**: Enforced via unique constraints for data consistency
   - **Minimal Indexes**: Only source + region + period indexes (keeps queries fast, row counts bounded)
   - **Automatic Cleanup**: Old partitions and raw JSON automatically removed

### Query Flow
1. User enters ZIP code OR coordinates on home page
2. Dashboard loads with all 4 data sources
3. Rails queries Oracle rollup tables based on location/filters
4. Data displayed in interactive charts and map
5. LLM chat queries Oracle via LangChain tools
6. Ollama generates natural language responses

## Filter Capabilities

### OpenAQ (Air Quality)
- **Location**: ZIP code or coordinates (10km radius)
- **Time Range**: 7-180 days (dropdown)
- **Data**: PM2.5 and O3 daily averages
- **Updates**: Hourly

### Hospital Capacity
- **Location**: ZIP code or coordinates (10km radius, finds nearby ZIPs)
- **Time Range**: 7-180 days (dropdown)
- **Data**: Total beds, occupied beds, ICU beds, COVID patients
- **Updates**: Daily at 3 AM

### Flu Activity
- **Location**: National, Auto-detect, or any US state (dropdown)
- **Time Range**: 4-52 weeks (dropdown, shows days equivalent)
- **Data**: Weighted ILI percentage (flu-like illness)
- **Updates**: Weekly (Mondays 2 AM)

### FDA Recalls
- **Location**: All States (default) or specific state (optional dropdown)
- **Time Range**: 7-180 days (dropdown)
- **Data**: Drug recalls and enforcement actions
- **Updates**: Daily at 4 AM

## Project Structure

```
healthcare/
├── app/
│   ├── controllers/        # Rails controllers (dashboard, chat, metrics)
│   ├── models/             # ActiveRecord models for all data sources
│   ├── jobs/               # Sidekiq ingestion jobs (4 jobs)
│   └── views/              # ERB templates with Tailwind CSS
├── fastapi_service/        # LLM microservice
│   ├── main.py             # FastAPI app
│   └── llm_service.py      # LangChain + Ollama integration
├── db/migrate/             # Oracle schema migrations
├── prometheus/             # Prometheus config
├── grafana/                # Grafana dashboards
└── docker-compose.yml      # All services orchestration
```

## Monitoring

### Prometheus Metrics
- `ingestion_duration_seconds` - Ingestion job duration by source
- `ingestion_records_total` - Records processed by source and status
- `ingestion_errors_total` - Ingestion errors by source
- `llm_query_duration_seconds` - LLM query latency
- `llm_queries_total` - LLM query count

### Grafana Dashboards
- **Data Ingestion Health** - Ingestion job performance and health
- **LLM Query Latency** - LLM service performance metrics

Access Grafana at http://localhost:3001 (admin/admin)

## Development

### Running Jobs Manually
```bash
# Run a specific ingestion job
docker-compose exec rails bundle exec rails runner "DelphiFluviewIngestionJob.perform_now"
docker-compose exec rails bundle exec rails runner "DelphiHospitalIngestionJob.perform_now"
docker-compose exec rails bundle exec rails runner "FdaEnforcementIngestionJob.perform_now"
docker-compose exec rails bundle exec rails runner "OpenAqIngestionJob.perform_now"

# Run with parameters (e.g., coordinates for OpenAQ)
docker-compose exec rails bundle exec rails runner "OpenAqIngestionJob.perform_now(nil, nil, 40.7128, -74.0060, 10)"
```

### Database Access
```bash
# Connect to Oracle
docker-compose exec oracle sqlplus system/healthsignal123@localhost:1521/HEALTHSIGNAL

# Run migrations
docker-compose exec rails bundle exec rails db:migrate

# Check database schema
docker-compose exec rails bundle exec rails db:schema:dump
```

### Viewing Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f rails
docker-compose logs -f sidekiq
docker-compose logs -f fastapi
docker-compose logs -f ollama
```

### Environment Variables
See `env.example` for all required environment variables:
- `OPENAQ_API_KEY` - Required for OpenAQ API access
- `DATABASE_URL` - Oracle connection string
- `REDIS_URL` - Redis connection for Sidekiq
- `FASTAPI_URL` - FastAPI service URL
- `RAILS_ENV` - Rails environment (development/production)

## API Endpoints

### Rails Application
- `GET /` - Home page with search form
- `GET /dashboard/:zip` - Dashboard for ZIP code
- `GET /dashboard/search?lat=X&lon=Y` - Dashboard for coordinates
- `POST /chat` - LLM-powered chat endpoint
- `GET /metrics` - Prometheus metrics endpoint

### FastAPI Service
- `POST /chat` - Process chat queries with LangChain + Ollama
- `GET /health` - Health check endpoint

## Database Maintenance

### Raw JSON Retention
- **Processed records**: Deleted after 7 days
- **Failed records**: Retained for 30 days (for investigation)
- **Automatic cleanup**: Run `rake cleanup:raw_ingestion_logs` or schedule via cron

### Partition Management
- Tables automatically partitioned by time (daily/weekly intervals)
- Old partitions can be dropped manually if needed
- Oracle handles partition pruning automatically for time-range queries

### Cleanup Tasks
```bash
# Clean up old raw ingestion logs
docker-compose exec rails bundle exec rake cleanup:raw_ingestion_logs

# Clean up old ingestion metrics
docker-compose exec rails bundle exec rake cleanup:ingestion_metrics

# Clean up everything
docker-compose exec rails bundle exec rake cleanup:all
```

## Notes

- **Oracle Instant Client** is included in the Rails Docker image
- **Ollama models** are downloaded on first use (can take time, ~4GB for llama2)
- **All services run locally** - no external API costs for LLM
- **Coordinate search** uses 10km radius by default
- **Auto-detection** for flu region uses hospital data to find state from ZIP/coordinates
- **Idempotent upserts** ensure data consistency even if jobs run multiple times
- **Time-series partitioning** keeps queries fast and row counts bounded
- **Raw JSON staging** allows reprocessing failed data and debugging


