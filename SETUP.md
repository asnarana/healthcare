# Health Radar - Setup Guide

## Prerequisites

1. **Docker & Docker Compose** - Install from https://www.docker.com/
2. **OpenAQ API Key** (free) - Get at https://openaq.org/

## Step-by-Step Setup

### 1. Configure Environment

```bash
# Copy example environment file
cp .env.example .env

# Edit .env and add your OpenAQ API key
# OPENAQ_API_KEY=your_key_here
```

### 2. Start Docker Services

```bash
# Start all services (this will take a few minutes on first run)
docker-compose up -d

# Watch logs
docker-compose logs -f
```

### 3. Initialize Database

Wait for Oracle to be healthy (check with `docker-compose ps`), then:

```bash
# Run migrations to create Oracle schema
docker-compose exec rails bundle exec rails db:migrate
```

### 4. Download Ollama Model (First Time Only)

```bash
# This downloads the LLM model (can take 10-20 minutes)
docker-compose exec ollama ollama pull llama2

# Or use a smaller model for faster startup:
docker-compose exec ollama ollama pull mistral
```

Then update `fastapi_service/llm_service.py` to use `mistral` instead of `llama2` if desired.

### 5. Run Initial Data Ingestion

```bash
# Manually trigger all ingestion jobs to populate data
docker-compose exec rails bundle exec rails healthsignal:ingest_all
```

Or wait for scheduled jobs to run (see `config/initializers/sidekiq.rb` for schedule).

### 6. Access Services

- **Rails App**: http://localhost:3000
- **Grafana**: http://localhost:3001 (admin/admin)
- **Prometheus**: http://localhost:9090
- **FastAPI**: http://localhost:8000/docs (API docs)

## Troubleshooting

### Oracle Connection Issues

```bash
# Check Oracle is running
docker-compose ps oracle

# Test connection
docker-compose exec oracle sqlplus system/healthsignal123@localhost:1521/HEALTHSIGNAL
```

### Sidekiq Not Processing Jobs

```bash
# Check Sidekiq logs
docker-compose logs sidekiq

# Restart Sidekiq
docker-compose restart sidekiq
```

### Ollama Model Not Found

```bash
# List available models
docker-compose exec ollama ollama list

# Pull model if missing
docker-compose exec ollama ollama pull llama2
```

### Rails App Errors

```bash
# Check Rails logs
docker-compose logs rails

# Restart Rails
docker-compose restart rails
```

## Next Steps

1. Enter a ZIP code on the dashboard (e.g., 10001 for NYC)
2. View health data charts and map
3. Try the chat feature to ask questions about health data
4. Check Grafana dashboards for ingestion health and LLM latency

## Maintenance

### Clean Up Old Raw Data

```bash
# Remove raw ingestion logs older than 30 days
docker-compose exec rails bundle exec rails healthsignal:cleanup_raw_logs
```

### View Database

```bash
# Connect to Oracle
docker-compose exec oracle sqlplus system/healthsignal123@localhost:1521/HEALTHSIGNAL

# Example queries:
# SELECT COUNT(*) FROM fluview_weekly_rollups;
# SELECT * FROM ingestion_metrics ORDER BY job_run_at DESC FETCH FIRST 10 ROWS ONLY;
```

## Production Considerations

- Set strong passwords in `.env` (not the defaults)
- Configure proper CORS origins in FastAPI
- Set up SSL/TLS for production
- Configure backup strategy for Oracle
- Monitor disk space (Oracle and Prometheus can grow large)
- Set up log rotation
- Configure proper firewall rules

