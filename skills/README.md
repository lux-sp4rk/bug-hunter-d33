# Bug Hunter D33 — Skill Registry

This directory contains the specialized hunting skills that power the Bug Hunter.

Each skill is a self-contained script that can be invoked independently.

## Available Skills

| Skill | File | Purpose | Default Model |
|-------|------|---------|---------------|
| Logic Hunt | `logic_hunt.sh` | Edge cases, null pointers, race conditions | trinity-mini |
| Security Hunt | `security_hunt.sh` | Vulnerabilities, auth gaps, injection | trinity-mini |
| Performance Hunt | `performance_hunt.sh` | N+1s, leaks, inefficiency | trinity-mini |
| Judge | `judge_hunt.sh` | Verify findings, remove false positives, deduplicate, re-rank | trinity-mini |

## Usage

Each skill follows the same interface:

```bash
./skills/<skill_name>.sh <file> <diff_content> [model]
```

Outputs: JSON array of findings to stdout

Example:
```bash
./skills/logic_hunt.sh "src/auth.py" "$DIFF_CONTENT" "arcee/trinity-large"
```

## Adding New Skills

1. Create `skills/your_skill.sh` following the template
2. Add prompt to `prompts/your-skill.md`
3. Register in `agent.yml` passes configuration
4. Update this README

## The Ancient Ways

The Ritual of Three Passes is now powered by these specialized skill modules.
Each hunter masters their domain. Together, no bug escapes.

---
*In the skills/ folder, mastery is modular.*
