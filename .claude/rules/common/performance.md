# Performance Optimization

## General Principles

- Measure before optimizing — profile to find actual bottlenecks, not assumed ones
- Optimize the critical path first — the 20% of code that runs 80% of the time
- Prefer algorithmic improvements over micro-optimizations (O(n) vs O(n²) beats caching a loop)
- Avoid premature optimization — write clear code first, optimize when profiling demands it

## Algorithmic Complexity

- Know your data structures — choose the right one for the access pattern
- Avoid O(n²) loops where O(n) or O(n log n) alternatives exist
- Use hash-based lookups (Map, dict, Set) instead of linear scans for membership checks
- Batch operations — prefer bulk inserts/updates over one-at-a-time loops

## Memory Efficiency

- Stream large datasets instead of loading them entirely into memory
- Use generators / iterators for lazy evaluation when full materialization isn't needed
- Release resources promptly — close files, connections, and cursors when done
- Avoid retaining references to objects beyond their useful lifetime

## I/O Performance

- Minimize round trips — batch API calls, use bulk queries, pipeline commands
- Parallelize independent I/O operations (concurrent fetches, parallel file reads)
- Cache frequently accessed data with appropriate TTLs
- Use connection pooling for databases and HTTP clients
- Compress data in transit (gzip, brotli) for network-bound workloads

## Database Performance

- Index columns used in WHERE, JOIN, and ORDER BY clauses
- Use EXPLAIN/EXPLAIN ANALYZE to understand query plans
- Avoid N+1 queries — use JOINs, subqueries, or batch fetches
- Paginate large result sets — never fetch unbounded rows
- Use read replicas for read-heavy workloads

## Caching Strategy

- Cache at the right layer (CDN, application, database, computation)
- Set appropriate TTLs — short for volatile data, long for stable data
- Invalidate caches on writes — prefer write-through or explicit invalidation over TTL-only
- Cache-aside pattern: check cache first, on miss fetch and populate

## Concurrency

- Use async I/O for I/O-bound work (network, disk, database)
- Use thread pools / worker pools for CPU-bound work
- Avoid blocking the main thread / event loop
- Limit concurrency — unbounded parallelism causes resource exhaustion
- Use backpressure patterns when producers outpace consumers

## Build and Deploy Performance

- Incremental builds — avoid full rebuilds when only part of the codebase changed
- Tree-shake unused code in production bundles
- Lazy-load non-critical modules and features
- Minimize dependency count — each dependency adds build time and attack surface

## Performance Checklist

- [ ] Profiled with real-world data and usage patterns
- [ ] Identified and addressed the critical path bottleneck
- [ ] Database queries use proper indexes and avoid N+1
- [ ] I/O operations are batched or parallelized where possible
- [ ] Large datasets use streaming or pagination, not full materialization
- [ ] Caching is applied at appropriate layers with invalidation strategy
- [ ] Concurrency is bounded and does not cause resource exhaustion
