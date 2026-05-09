# Pipeline Health Watchdog — Extension Spec

**Date:** 2026-05-09
**Author:** Board Advisor
**Target:** CTO (when Codex tokens reset)
**Reads:** `C:/QM/paperclip/tools/ops/pipeline_health_watchdog.py`
**Trigger:** OWNER directive 2026-05-09 — keepalive loop on QUA-712 went unnoticed for ~2h, costing both Claude and Codex tokens; watchdog itself had a silent comment-post bug.

## Goal

Catch the next runaway / cap-hit / stranded-dispatcher event in <30 minutes, not 2 hours.

## Three new detectors

### Detector A — Anthropic monthly-cap-hit (systemic adapter-error)

**Pattern observed previously:** N agents simultaneously flip to `status=error` within 5 min. Per memory `feedback_anthropic_org_monthly_cap_failure_mode.md`, the heartbeat-runs message contains "You've hit your org's monthly usage limit".

**Detection logic:**
```python
def check_systemic_adapter_error():
    # GET all agents from API
    # Count agents whose status='error' in last 5 min
    # If count >= 3 in that window → cap-hit alarm (severity=critical)
```

**Severity:** `critical` — surfaces immediately, no idle-threshold delay.
**Action:** post to QUA-1160 with verbatim error-message excerpt. Don't auto-pause; OWNER-class decision.

### Detector B — Dispatcher-down (cohort idle, not individual)

**Pattern observed today:** HoP looped on QUA-712 → 5 sub-agents (P2-Baseline-Runner, Phase-Runner-P3plus, Setfile-Engineer, Zero-Trades-Specialist, Framework-Guardian) sat idle simultaneously. Current watchdog only flags after 2h per individual sub.

**Detection logic:**
```python
COHORT_IDLE_THRESHOLD_MIN = 30  # was 120 (2h) for individual
# If >= 3 monitored sub-agents have 0 runs in last 30 min while pipeline has open in_progress P-phase work
# → dispatcher-down alarm (severity=high)
```

**Severity:** `high` — points the finger at HoP/CTO not the subs.
**Action:** post to QUA-1160 + name the dispatcher (HoP or CTO based on ownership of the open in_progress issues).

### Detector C — Repeated-content comment storm

**Pattern observed today:** HoP posted ~30 near-identical "Concrete heartbeat action completed for QUA-712" comments in 1h. Watchdog's HoP-loop alarm catches the *count* but not the *content-identity* failure.

**Detection logic:**
```python
def check_comment_content_loops():
    # For each issue with comments in last 60 min:
    #   - hash each comment body (first 200 chars, normalized whitespace)
    #   - if any hash appears >= 3 times from same author in 60 min → loop
```

**Severity:** `high`.
**Action:** post to QUA-1160 with issue + author + repetition count. Independent from HoP-loop count metric.

## Three reliability fixes (lessons from today)

1. **Replace `?limit=200` issue lookup** with direct identifier lookup (already patched today after diagnosis).
2. **Loud-fail mode in `post()`/`safe_fetch()`** — log to stderr AND append to `docs/ops/api_failures/<date>.jsonl` instead of silently returning `None` on HTTPError.
3. **Self-test mode** — `python pipeline_health_watchdog.py --self-test` runs all detectors against fake state and verifies tracker post lands. Add to a new `QM_PipelineHealth_Watchdog_SelfTest_Daily` Windows task at 06:00 local.

## Acceptance gates (DL-054 style)

- All 4 existing detectors still fire correctly
- 3 new detectors each demonstrated with a synthetic test
- `--self-test` exits 0 on success, non-zero on failure
- `docs/ops/api_failures/<date>.jsonl` shows entries when API returns non-2xx
- One end-to-end run posts a comment to QUA-1160 and the comment persists

## Out of scope

- Auto-remediation (don't auto-disable agents, don't auto-cancel issues; alarm only)
- Anthropic-billing API integration (already have `/costs/quota-windows` per memory `reference_paperclip_quota_windows_api.md` — separate spec if OWNER wants live %used in dashboard)
