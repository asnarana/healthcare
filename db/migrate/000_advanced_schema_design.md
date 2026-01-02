# Advanced Oracle Schema Design (Saved for Later)

## Time-Series Rollup Design

This document contains the advanced schema design that was simplified for initial implementation.

### Key Features:
1. **Daily/Weekly rollups as canonical** - Main storage in aggregated tables
2. **Raw JSON staging** - Temporary storage (7-30 day retention) for debugging
3. **Partitioning by time** - Monthly/yearly partitions for fast queries
4. **Unique keys + upserts** - Idempotent data insertion
5. **Minimal indexes** - Only source + region + period indexes

### Implementation Notes:
- Use Oracle interval partitioning for automatic partition management
- Raw JSON table should be cleaned up periodically
- Rollup tables are the source of truth
- Indexes kept minimal to prevent unbounded growth

### When to Implement:
- When data volume grows significantly
- When query performance degrades
- When you need to reprocess historical data
- When you need to debug ingestion issues

