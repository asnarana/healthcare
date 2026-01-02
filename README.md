# Health Radar

A health data monitoring dashboard I built to track air quality, hospital capacity, flu activity, and FDA recalls. Uses Rails 7, Oracle Database, and a local LLM for answering questions about the data.

## What It Does

You can search by ZIP code or coordinates and see health data for that area. The dashboard shows:
- Air quality (PM2.5 and O3) - updates hourly
- Hospital bed availability - updates daily
- Flu activity levels - updates weekly
- FDA drug recalls - updates daily

There's also a chat feature where you can ask questions about the data using natural language, powered by Ollama running locally.

## Tech Stack

- Rails 7 with Hotwire, Tailwind CSS, and MapLibre for the frontend
- Sidekiq + Redis for background jobs
- Oracle Database Free (running in Docker)
- FastAPI microservice with LangChain + Ollama for the LLM chat
- Prometheus + Grafana for monitoring

## Data Sources

I'm pulling data from 4 APIs:
1. **Delphi FluView** - Weekly flu data (national + all 50 states)
2. **Delphi Hospital Capacity** - Daily hospital bed counts
3. **openFDA** - Drug recalls and enforcement actions
4. **OpenAQ** - Air quality measurements (requires free API key)

## Getting Started

### What You Need
- Docker and Docker Compose installed
- OpenAQ API key (get one free at https://openaq.org/)

### Setup Steps

1. Clone the repo and set up environment:
   ```bash
   git clone https://github.com/asnarana/healthcare.git
   cd healthcare
   cp env.example .env
   ```
   Then edit `.env` and add your `OPENAQ_API_KEY`.

2. Start everything:
   ```bash
   docker-compose up -d
   ```
   This starts all the services (Rails, Oracle, Redis, Sidekiq, FastAPI, Ollama, Prometheus, Grafana).

3. Run the database migrations:
   ```bash
   docker-compose exec rails bundle exec rails db:migrate
   ```

4. Download the Ollama model (first time only, takes a few minutes):
   ```bash
   docker-compose exec ollama ollama pull llama2
   ```

5. Access the app:
   - Main app: http://localhost:3000
   - Grafana: http://localhost:3001 (admin/admin)
   - Prometheus: http://localhost:9090
   - FastAPI: http://localhost:8000

## How It Works

### Data Ingestion

Background jobs run on a schedule:
- Flu data: Every Monday at 2 AM (weekly)
- Hospital data: Daily at 3 AM
- FDA recalls: Daily at 4 AM
- Air quality: Every hour

The jobs follow a 3-step process:
1. **Fetch** - Get raw JSON from the API and store it temporarily
2. **Process** - Extract and aggregate data into rollup tables (this is the canonical storage)
3. **Cleanup** - Delete old raw JSON after 7-30 days

### Database Design

I designed the Oracle schema as time-series rollups:
- **Daily/weekly/hourly aggregates** are the canonical data (not raw JSON)
- **Partitioning by time** - all tables are partitioned so queries stay fast
- **Raw JSON staging** - kept for 7-30 days for debugging, then auto-deleted
- **Unique keys + upserts** - prevents duplicate data even if jobs run multiple times
- **Minimal indexes** - only source + region + period indexes to keep things fast

This keeps row counts bounded and queries fast even as data grows.

### Using the Dashboard

1. Go to the home page and enter a ZIP code (or coordinates)
2. The dashboard loads showing all 4 data sources
3. You can adjust time ranges for each chart independently
4. For flu data, you can select national or state-level
5. For FDA recalls, you can optionally filter by state
6. The map shows hospital locations and air quality stations
7. Use the chat to ask questions about the data

### Filters

Each data source has its own filters:

**Air Quality & Hospital:**
- Location is set when you search (ZIP or coordinates)
- Time range: 7, 14, 30, 60, 90, or 180 days

**Flu Activity:**
- Region: National, Auto-detect (from your location), or any state
- Time range: 4, 8, 12, 16, 24, or 52 weeks

**FDA Recalls:**
- State: All states (default) or filter by specific state
- Time range: 7, 14, 30, 60, 90, or 180 days

## Project Structure

```
healthcare/
├── app/
│   ├── controllers/     # Dashboard, chat, metrics controllers
│   ├── models/          # ActiveRecord models
│   ├── jobs/            # 4 Sidekiq ingestion jobs
│   └── views/           # ERB templates
├── fastapi_service/     # LLM microservice
├── db/migrate/          # Oracle schema
├── prometheus/          # Prometheus config
├── grafana/            # Grafana dashboards
└── docker-compose.yml   # All services
```

## Monitoring

Prometheus tracks:
- How long ingestion jobs take
- How many records are processed
- Ingestion errors
- LLM query latency

Grafana dashboards show:
- Data ingestion health
- LLM query performance

Access Grafana at http://localhost:3001 (admin/admin)

## Development

### Running Jobs Manually

```bash
# Run a specific job
docker-compose exec rails bundle exec rails runner "DelphiFluviewIngestionJob.perform_now"

# Run with parameters (e.g., coordinates for OpenAQ)
docker-compose exec rails bundle exec rails runner "OpenAqIngestionJob.perform_now(nil, nil, 40.7128, -74.0060, 10)"
```

### Database Access

```bash
# Connect to Oracle
docker-compose exec oracle sqlplus system/healthsignal123@localhost:1521/HEALTHSIGNAL

# Run migrations
docker-compose exec rails bundle exec rails db:migrate
```

### Viewing Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f rails
docker-compose logs -f sidekiq
```

## Database Maintenance

### Raw JSON Cleanup

Raw JSON is kept temporarily for debugging:
- Processed records: deleted after 7 days
- Failed records: kept for 30 days (for investigation)

Run cleanup:
```bash
# Clean up old raw logs
docker-compose exec rails bundle exec rake cleanup:raw_ingestion_logs

# Clean up old metrics
docker-compose exec rails bundle exec rake cleanup:ingestion_metrics

# Clean up everything
docker-compose exec rails bundle exec rake cleanup:all
```

### Partitioning

Tables are automatically partitioned by time. Oracle handles partition pruning for time-range queries automatically. Old partitions can be dropped manually if you need to free up space.

## API Endpoints

**Rails:**
- `GET /` - Home page
- `GET /dashboard/:zip` - Dashboard for ZIP code
- `GET /dashboard/search?lat=X&lon=Y` - Dashboard for coordinates
- `POST /chat` - LLM chat endpoint
- `GET /metrics` - Prometheus metrics

**FastAPI:**
- `POST /chat` - Process chat queries
- `GET /health` - Health check

## Notes

- Oracle Instant Client is included in the Rails Docker image
- Ollama models download on first use (~4GB for llama2, takes a few minutes)
- Everything runs locally - no external API costs for the LLM
- Coordinate search uses 10km radius by default
- Auto-detection for flu region uses hospital data to find your state
- Idempotent upserts mean you can run jobs multiple times safely
- Partitioning keeps queries fast as data grows

## License

MIT

## Author

Amrish Naranappa (asnarana@ncsu.edu)
