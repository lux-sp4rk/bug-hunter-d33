# Framework Skills for Bug Hunter D33

Pre-committed skills from skills.sh for zero-dependency CI runs.

## Available Skills

| Framework | File | Source | Detected By |
|-----------|------|--------|-------------|
| React/Next.js | `react-vercel.md` | vercel-labs/agent-skills | JSX/TSX, React imports |
| Godot Development | `godot-gamedev.md` | zate/cc-godot | .gd files, @onready |
| Supabase/Postgres | `supabase-postgres.md` | supabase/agent-skills | SQL files, Supabase imports |
| Security Review | `security-review.md` | ghostsecurity/skills | Security-focused passes |

## Detection Mapping

Frameworks are auto-detected from the diff:

```bash
# React/Next.js
- import React / from 'react'
- .jsx / .tsx extensions
- from 'next/' imports

# Godot
- .gd extensions
- @onready / extends Node

# Supabase/Postgres
- .sql files
- from '@supabase/supabase-js'
- supabase.rpc(), supabase.from()

# Security (always available)
- Applied during security hunter pass
```

## Adding New Skills

To refresh or add a skill from skills.sh:

```bash
# Fetch skill content
npx skills fetch owner/skill-name > framework-skills/skill-name.md

# Update action.yml detection logic
# Update this README
# Commit and push
```

## Why Local?

- Zero network dependency during CI
- Deterministic reviews (skill version pinned)
- Faster execution (no fetch latency)
- Works on any runner (GitHub-hosted or self-hosted)

## Skill Sources

| Skill | Source | License |
|-------|--------|---------|
| React Best Practices | vercel-labs/agent-skills | MIT |
| Godot Development | zate/cc-godot | MIT |
| Supabase Postgres | supabase/agent-skills | Apache 2.0 |
| Security Review | ghostsecurity/skills | Commercial |
