# Health Radar

A comprehensive health data monitoring dashboard built with Rails 7, Oracle Database, and LLM-powered chat.

## Architecture

### Stack
- **Rails 7** + Hotwire + Tailwind CSS + MapLibre
- **Sidekiq** + Redis for background job processing
- **Oracle Database Free** (gvenzl/oracle-free) with time-series optimized schema
- **FastAPI** microservice with LangChain + Ollama (local LLM)
- **Prometheus** + **Grafana** for monitoring

### Data Sources
1. **Delphi FluView** - Weekly influenza-like illness data
2. **Delphi Hospital Capacity** - Daily hospital bed availability
3. **openFDA** - Drug enforcement and recall data
4. **OpenAQ** - Air quality measurements (PM2.5, O3)

## Quick Start

### Prerequisites
- Docker and Docker Compose
- OpenAQ API key (free at https://openaq.org/)

### Setup

1. **Clone and configure:**
   ```bash
   cp .env.example .env
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
   - Delphi FluView: Weekly (Mondays 2 AM)
   - Delphi Hospital: Daily (3 AM)
   - openFDA: Daily (4 AM)
   - OpenAQ: Hourly

2. **Data Processing:**
   - Raw JSON stored in `raw_ingestion_logs` (7-30 day retention)
   - Aggregated data stored in rollup tables (canonical storage)
   - Idempotent upserts prevent duplicates

3. **Oracle Schema:**
   - Time-series optimized with partitioning
   - Daily/weekly rollups as canonical data
   - Minimal indexes (source + region + period)

### Query Flow
1. User enters ZIP code on dashboard
2. Rails queries Oracle rollup tables
3. Data displayed in charts and map
4. LLM chat queries Oracle via LangChain tools
5. Ollama generates natural language responses

## Project Structure

```
healthcare/
├── app/
│   ├── controllers/        # Rails controllers
│   ├── models/             # ActiveRecord models
│   ├── jobs/               # Sidekiq ingestion jobs
│   └── views/              # ERB templates with Tailwind
├── fastapi_service/        # LLM microservice
│   ├── main.py             # FastAPI app
│   └── llm_service.py      # LangChain + Ollama integration
├── db/migrate/             # Oracle schema migrations
├── prometheus/             # Prometheus config
├── grafana/                # Grafana dashboards
└── docker-compose.yml      # All services
```

## Monitoring

### Prometheus Metrics
- `ingestion_duration_seconds` - Ingestion job duration
- `ingestion_records_total` - Records processed
- `ingestion_errors_total` - Ingestion errors
- `llm_query_duration_seconds` - LLM query latency
- `llm_queries_total` - LLM query count

### Grafana Dashboards
- **Data Ingestion Health** - Ingestion job performance
- **LLM Query Latency** - LLM service performance

## Development

### Running Jobs Manually
```bash
# Run a specific ingestion job
docker-compose exec rails bundle exec rails runner "DelphiFluviewIngestionJob.perform_now"

# Check Sidekiq web UI (if enabled)
# Access at http://localhost:3000/sidekiq
```

### Database Access
```bash
# Connect to Oracle
docker-compose exec oracle sqlplus system/healthsignal123@localhost:1521/HEALTHSIGNAL
```

### Viewing Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f rails
docker-compose logs -f sidekiq
docker-compose logs -f fastapi
```

## Notes

- **Oracle Instant Client** is included in the Rails Docker image
- **Ollama models** are downloaded on first use (can take time)
- **Raw JSON retention** is configurable (default 30 days)
- **All services run locally** - no external API costs for LLM

## License

MIT

