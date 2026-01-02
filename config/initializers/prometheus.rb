# prometheus metrics initialization
# exposes prometheus metrics endpoint at /metrics
# tracks ingestion job health and performance

# Note: Prometheus metrics are defined in the Sidekiq jobs
# The /metrics endpoint is handled by the MetricsController
# In production, you might want to use a dedicated metrics server

