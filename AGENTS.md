# AGENTS.md — Bug Hunter D33 Operational Protocol

*Behavioral core lives in [SOUL.md](SOUL.md). This file governs operations.*

---

## 1. SESSION START (Summoning)

The hunter awakens when summoned via GitHub Actions or OpenClaw subagent invocation.

### Prerequisites Check
```bash
# Required environment
ARCEE_API_KEY=<valid_api_key>     # Hunter's blade — cannot hunt without
MODEL=arcee/trinity-mini          # Default weapon; override per skill if needed

# Optional overrides
LOGIC_MODEL=<model>               # Override for logic hunter
SECURITY_MODEL=<model>            # Override for security hunter  
PERFORMANCE_MODEL=<model>         # Override for performance hunter
PASSES=logic,security             # Which skills to summon
MAX_FILES=20                      # Limit scope for speed
```

### Validation Ritual
1. Verify `ARCEE_API_KEY` is set and non-empty
2. Confirm `skills/` directory exists and all skills are executable
3. Check git state (must be in a repo with fetchable history)
4. Load changed files list
5. If no files changed → status=success, exit cleanly

### Checkpoint
```bash
# Log hunt parameters for debugging
echo "[Bug Hunter D33] Model: $MODEL | Passes: $PASSES | Files: $file_count"
```

---

## 2. THE HUNT (Session Execution)

### Skill Invocation Order
Skills are summoned in the order specified by `PASSES` (comma-separated):

```
logic → security → performance
```

Each skill is invoked independently with:
- File path
- Diff content (truncated to 15KB)
- Model override (if specified)

### Retry Protocol
Each skill call follows triple-redundancy:
1. **First attempt** — Direct API call
2. **Second attempt** — 2s backoff (transient network)
3. **Third attempt** — 4s backoff (API pressure)

After 3 failures → skill returns empty array `[]`, hunt continues.

### Output Aggregation
- Each skill outputs JSON array of findings
- Findings are merged: `all_findings = logic_findings + security_findings + performance_findings`
- File attribution added if missing from skill output
- Deduplication: Currently none (future: hash on file+line+message)

### Progress Logging
```bash
[Hunt Start] Tracking N files...
[Skill Call] Summoning {skill} hunter for {file}...
[Hunt End] Found: X critical, Y warnings
```

---

## 3. SESSION END (Dismissal)

### Persistence
- `findings.json` — Full JSON array of all findings
- `status` — `success` | `warning` | `failure`
- GitHub Actions outputs set (if running in CI)

### Status Determination
| Critical | Warnings | Status |
|----------|----------|--------|
| 0        | 0        | success |
| 0        | >0       | warning |
| >0       | any      | failure |

### Cleanup
- Remove temp files (none currently; skills write to stdout only)
- Leave `.bug-hunter/` directory for post-hunt inspection

### Handoff
If invoked as subagent, return structured result:
```json
{
  "status": "warning",
  "findings": [...],
  "critical_count": 0,
  "warning_count": 3,
  "files_reviewed": 5,
  "skills_invoked": ["logic", "security"]
}
```

---

## 4. ERROR HANDLING

| Error | Response | Exit Code |
|-------|----------|-----------|
| Missing ARCEE_API_KEY | Log fatal, status=failure | 1 |
| No files to review | Log info, status=success | 0 |
| Skill returns invalid JSON | Log warning, continue | 0 |
| All skills fail | Log warning, status=warning | 0 |
| API rate limited (429) | Retry with backoff | 0 (if eventual success) |
| Critical findings found | status=failure | 1 |

---

## 5. EXTERNAL INTEGRATION

### GitHub Actions
Entry point: `action.yml` → `scripts/summon.sh`
- Automatic PR comment posting
- Check run creation
- Inline annotations (future)

### OpenClaw Subagent
Entry point: `agent.yml` → `scripts/summon.sh`
- Spawn via: `openclaw agent --agent bug-hunter-d33 --task "review PR #N"`
- Returns structured JSON for parent agent consumption

### Local Invocation
```bash
# Direct skill test
./skills/logic_hunt.sh "src/file.py" "$(git diff HEAD -- src/file.py)"

# Full hunt
ARCEE_API_KEY=xxx ./scripts/summon.sh
```

---

## 6. EXTENDING THE HUNT

To add a new skill (e.g., `style_hunt`):

1. Create `skills/style_hunt.sh` following the skill interface
2. Add prompt to `prompts/style-hunter.md`
3. Register in `agent.yml` passes section
4. Update `PASSES` default or call explicitly with `PASSES=style`

No changes needed to `summon.sh` — it dynamically discovers skills.

---

## 7. SAFETY & PRIVACY

- **API Keys**: Never logged, never cached, passed via env only
- **Code**: Never leaves the hunt context (sent to Arcee API only)
- **Logs**: File paths may appear in logs; diff content does not
- **Retention**: Findings.json persists until next hunt or manual cleanup

---

## Quick Reference

| Task | Command |
|------|---------|
| Summon for PR review | Uses GitHub Action |
| Summon as subagent | `openclaw agent --agent bug-hunter-d33` |
| Test single skill | `./skills/logic_hunt.sh <file> <diff>` |
| Override all models | `MODEL=arcee/trinity-large ./scripts/summon.sh` |
| Security only, strict | `PASSES=security SECURITY_MODEL=trinity-large ./scripts/summon.sh` |

---

*Operational questions: See this file. Identity questions: See SOUL.md.*
*The hunter is summoned. The hunt follows protocol. The quarry is found.*
