# Bug Hunter D33

*"In a world of infinite code, someone must hunt the bugs that dwell in the shadows."*

A dual-purpose code review system: GitHub Action for CI/CD, OpenClaw subagent for runtime hunting.

## Summoning

### As GitHub Action
```yaml
uses: lux-sp4rk/bug-hunter-d33@main
with:
  arcee-api-key: ${{ secrets.ARCEE_API_KEY }}
  passes: logic,security,performance
```

### As Subagent
```bash
openclaw agent --agent bug-hunter-d33 --task "review PR #193"
```

## The Three Passes

Every hunt follows the ancient ways:

1. **Logic Hunter** — Finds edge cases, broken assumptions, silent failures
2. **Security Hunter** — Tracks vulnerabilities, auth gaps, injection paths
3. **Performance Hunter** — Hunts leaks, N+1s, inefficient patterns

## Configuration

| Input | Default | Description |
|-------|---------|-------------|
| `arcee-api-key` | required | Your Arcee API key |
| `model` | `arcee/trinity-mini` | Model to use for hunting |
| `passes` | `logic,security` | Which hunters to summon |
| `severity-threshold` | `warning` | `info` / `warning` / `error` |
| `custom-prompts` | — | Path to override prompts |

## The Hunters

See `SOUL.md` for the full persona.

---
*In the distance, a horse whinnies. The hunt begins.*

---

## Canonical Location

This repo is the canonical home for Bug Hunter D33.  
Mirror: [lux-sp4rk/bug-hunter-d33](https://github.com/lux-sp4rk/bug-hunter-d33) (archived)
