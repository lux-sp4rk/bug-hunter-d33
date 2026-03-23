# Supabase Postgres Best Practices
# Source: skills.sh/supabase/agent-skills/supabase-postgres-best-practices
# Committed to bug-hunter-d33 for zero-dependency CI

## Overview
Comprehensive performance optimization guide for Postgres, maintained by Supabase. Contains rules across 8 categories, prioritized by impact.

## Priority 1: Query Performance (CRITICAL)

- **query-missing-indexes** - Identify queries missing proper indexes
- **query-n-plus-one** - Detect and fix N+1 query patterns
- **query-select-star** - Avoid SELECT *, specify columns explicitly
- **query-large-offsets** - Use keyset pagination instead of large OFFSET

## Priority 2: Connection Management (CRITICAL)

- **conn-pooling** - Use connection pooling (PgBouncer/supavisor)
- **conn-limits** - Stay within connection limits
- **conn-transactions** - Keep transactions short
- **conn-prepared-statements** - Use prepared statements for repeated queries

## Priority 3: Security & RLS (CRITICAL)

- **security-rls-enabled** - Enable Row Level Security on all tables
- **security-rls-policies** - Write specific RLS policies, not broad ones
- **security-auth-uid** - Use auth.uid() correctly in policies
- **security-least-privilege** - Grant minimal permissions to roles

## Priority 4: Schema Design (HIGH)

- **schema-appropriate-types** - Use appropriate data types
- **schema-foreign-keys** - Use foreign keys with ON DELETE rules
- **schema-partial-indexes** - Create partial indexes for filtered queries
- **schema-normalization** - Normalize to 3NF, denormalize selectively

## Priority 5: Concurrency & Locking (MEDIUM-HIGH)

- **lock-row-level** - Prefer row-level locks over table locks
- **lock-advisory-locks** - Use advisory locks for application-level locking
- **lock-deadlock-prevention** - Order operations consistently

## Priority 6-8: Data Access, Monitoring, Advanced

- Use appropriate indexes (B-tree, GiST, GIN)
- Monitor slow queries with pg_stat_statements
- Use EXPLAIN ANALYZE for query optimization

## Bug Hunter Focus for Supabase

When reviewing Supabase/Postgres code, prioritize:
1. Missing RLS policies or overly permissive ones
2. N+1 queries in API routes
3. Missing indexes on foreign keys
4. Inefficient pagination (large OFFSET)
5. Connection leaks or long transactions
