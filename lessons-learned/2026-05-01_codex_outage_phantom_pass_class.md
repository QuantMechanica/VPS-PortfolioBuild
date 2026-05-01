# Lessons learned — 2026-05-01 outage class (Codex quota collapse + phantom-PASS matrix + cascading failures)

**Author:** Board Advisor 2026-05-01 — durable knowledge for the next quota / parser / governance failure.
**Status:** DRAFT for Doc-KM ratification (Doc-KM owns lessons-learned per DL-027).
**Scope:** All five compound failure modes that surfaced 2026-05-01, what they shared, and what mechanisms now exist to prevent recurrence.

## TL;DR

A single bad day surfaced **eight distinct failure modes** that share a common root cause: **the company had no continuous metric-watcher with authority to escalate before a threshold became an outage.** Each mode was knowable hours-to-days in advance from existing data; each was missed because nobody owned reading that data. The Tuesday-prep package (this and the DL-055 / DL-056 / DL-057 hires + 11 commits on `agents/board-advisor`) is the corrective.

## The eight failure modes

### 1. Codex token quota collapse (~12:00 UTC)

**What:** Codex API quota exhausted with 0 days warning. 4 codex_local agents (CTO, DevOps, Development, Pipeline-Op) dropped offline simultaneously until Tuesday 07:30 W. Europe.

**Why missed:** No agent or process was watching cumulative token consumption. Paperclip's `spentMonthlyCents` field is permission-filtered + does not reflect provider-side spend; Codex burn was entirely off-radar.

**Corrective:** **DL-056** Chief-of-Staff hire with explicit token-burn-watch scope + `framework/registry/token_budget.json` + `dl056_research_auto_wake.py` model... wait. Token budget is managed by CoS reading `framework/registry/token_budget.json`, hard-rule escalation when forecast hits 4-day exhaustion. Plus **DL-055** DevOps + QUA-527 daily snapshot infra (data producer).

### 2. Phantom-PASS matrix (QUA-662)

**What:** Pipeline-Op's QM5_1003 P2 matrix produced `report.csv` with 36/36 rows labeled PASS while its own `zero_trade_audit_20260501.json` recorded 36/36 zero-trade rows. Same harness, same timestamp, two contradictory files.

**Why:** Five concurrent failure modes that each could have produced a phantom row alone:
- (a) **Tester read-access broken** on ~21 imported `.DWX` symbols (`bars_one_shot=0` / `Terminal: Invalid params`); P0-21 readiness was prematurely stamped READY despite FAILs in the same log.
- (b) **`XBRUSD.DWX` hallucinated** into `.scratch/qua662_done_symbols.txt` — never imported.
- (c) **Symbol-name mismatch on indices** — `NDX.DWX` vs canonical `NDXm.DWX`, `GDAXI.DWX` vs `GDAXIm.DWX`.
- (d) **Wrong tester deposit** — live tester journal recorded `initial deposit 10000.00 USD`; OWNER mandate is 100,000.
- (e) **Anti-theater parser failure** — Pipeline-Op parsed `automatical testing finished` as success regardless of trade count.

**Corrective:** **DL-054** Anti-Theater Pass Criteria — five binding gates a run must pass before `verdict=PASS` may be written. Quality-Tech is gate-of-record on every matrix review. Gate library at `framework/scripts/dl054_gates.py` smoke-tested + CLI runner. v2 bar compilation script forced `CustomRatesUpdate` for 33 missing-history symbols (33 OK + 2 SKIP, 0 FAIL, 53M bars).

### 3. Premature `verdict=READY` on P0-21 setup verification

**What:** `D:/QM/mt5/T1/dwx_import/logs/hourly_2026-04-27.log` 09:48Z run printed `verdict=READY` AND `FAIL_tail_bars` lines for 21 symbols in the same run. The READY stamp was load-bearing for downstream Pipeline-Op dispatch — "verify says READY, dispatch."

**Why missed:** Whoever wrote `verify_import.py` decided the readiness verdict came from a high-level pass count; per-symbol FAIL lines were informational only. Result: a 75% partial pass still stamped READY.

**Corrective:** DL-054 Gate 1 reads filesystem hcc directly (the bars MT5 actually serves), not the verify-log verdict line. Stale verify-log failure tokens are filtered against hcc mtime; a fresh hcc invalidates an older FAIL token. P0-21 reopened in `PROJECT_BACKLOG.md` until 35/35 .DWX symbols pass DL-054 Gate 1 — re-closed 2026-05-01 after v2 compilation + propagation to T1-T5 byte-identical.

### 4. CoS itself becoming the keepalive-churn pattern it was hired to detect

**What:** Newly-hired CoS produced 46 comments in 38.6 minutes (72/hr) on QUA-699, becoming exactly the DL-046 violation pattern it was built to catch. Self-detected its own quota event mid-spam; meta-aware but couldn't self-fix because the wake came from a Paperclip harness misconfiguration.

**Why:** Paperclip's harness fired wake events ~every 45 seconds despite the agent's `intervalSec=3600` configuration. Anti-loop guards in the prompt don't override harness wake cadence.

**Corrective:** PATCHed `runtimeConfig.heartbeat.enabled=false` on CoS — wake-on-demand only. Paperclip platform team owns the harness wake-rate bug; CoS stays disabled until fixed. New memory `feedback_paperclip_agent_config_patch_works.md` codifies that config PATCHes are Board-Advisor-direct; lifecycle pause/resume remain OWNER-class.

### 5. Zombie `dispatch_state.json` rows blocking Research auto-wake

**What:** 15 in_flight rows from QM5_1002 broken loop never got `status=complete` markers. They sat in `dispatch_state.json` for 12+ hours, making the DL-057 auto-wake pulse think a matrix was still mid-run.

**Why:** Pipeline-Op crashed without proper cleanup. No reaper process pruned stale entries.

**Corrective:** Pulse script ignores entries older than 12h with no completion (zombie filter). Backup → `dispatch_state.json.before_zombie_purge_2026-05-01`; live state cleaned. Pipeline-Op should add a reaper on startup Tuesday.

### 6. `magic_numbers.csv` registry gap (Tuesday-blocking)

**What:** All 13 active ea_ids registered in `ea_id_registry.csv`, but only 1 (`1001/EURUSD`) had any rows in `magic_numbers.csv`. Pipeline-Op queries this CSV for `allowed_symbols` per ea_id; without rows, no symbols allowed → cannot dispatch. QM5_1003 (Tuesday's first baseline) had **zero rows** and would have failed to launch on every symbol.

**Why missed:** Two registries that must stay aligned, no cross-check process. Each agent that registered an ea_id (Development, CTO, Pipeline-Op) populated `ea_id_registry.csv` but no one populated `magic_numbers.csv`.

**Corrective:** Generated 466 rows covering all 12 missing ea_ids × canonical 36 symbols. New tool `framework/scripts/research_dedup_check.py audit` cross-checks ea_id_registry vs magic_numbers vs filesystem cards on demand. Tuesday Pipeline-Op runs `audit` before first dispatch.

### 7. DevOps QUA-671 keepalive-churn loop (114 commits/hr)

**What:** DevOps spamming `ops: refresh QUA-671 canonical blocked owner handoff heartbeat utc marker (active)` commits at ~120/hr. Each commit identical in shape; zero semantic delta. Pure DL-046 violation, but no enforcement caught it.

**Why:** A signal-file refresh task (`QM_AggregatorState_1min` + 3 sibling scheduled tasks) wrote to `docs/ops/QUA-671_BLOCKED_HEARTBEAT_*.md` every minute without gating on whether the content had actually changed.

**Corrective:** 4 scheduled tasks disabled (`QM_AggregatorState_1min`, `QM_QUA95_BlockerRefresh`, `QM_RuntimeHealthScan_15min`, `QM_InfraHealthCheck_5min`). DevOps agent paused (CEO via UI). Tuesday: CTO + DevOps fix the refresh script to gate on `if last_signal_content_hash == current_signal_content_hash: return`. Re-enable tasks one at a time with cadence monitoring.

### 8. Routing analysis findings as comments instead of acting

**What:** Board Advisor's earlier pattern this day was to write long QUA-684 comments recommending CEO PATCH actions instead of just performing the PATCH directly when in scope.

**Why:** Default-to-route reflex; conservative scope-reading; not internalizing that reversible config edits are Board-Advisor-direct.

**Corrective:** OWNER explicit correction 2026-05-01 ~13:18Z: *"everything should not produce comments or reviews, it should actually change and work!"* Saved as memory `feedback_act_directly_not_comment_route.md` — bias toward direct action when authorized + reversible + in scope; agent-pause stays OWNER-class.

## Common root cause across all eight modes

**Nobody was reading the data that already existed.**

- Mode 1: token spend was visible per-provider, just nobody watched.
- Mode 2: zero_trade_audit was right beside report.csv contradicting it.
- Mode 3: FAIL lines were in the same log as the READY stamp.
- Mode 4: anti-loop guards existed in the prompt, just not at the harness layer.
- Mode 5: dispatch_state.json had `ts` timestamps; nobody checked their age.
- Mode 6: ea_id_registry and magic_numbers had a structural alignment that wasn't enforced.
- Mode 7: identical commit hashes were generated minute-by-minute; visible in `git log`.
- Mode 8: scope rules were written but not internalized.

The Tuesday-prep package adds **active watchers + enforced gates** at every layer that previously relied on agents-noticing-things-themselves:

- **DL-054 gates** force `verdict=INVALID` on bad runs (replaces parser hope-it-works).
- **DL-056 CoS** continuously watches token + roster + model fit (replaces silence).
- **DL-057 auto-wake pulse** continuously polls queue state (replaces remember-to-wake-Research).
- **`research_dedup_check.py audit`** cross-checks registries (replaces alignment-is-someone-else's-job).
- **Zombie filter** in pulse script ignores stale state (replaces hope-Pipeline-Op-cleans-up).
- **Anti-theater memory** (`feedback_act_directly_not_comment_route.md`) shifts Board Advisor's default to act (replaces route-everything).

## What we did NOT solve

- **Paperclip harness wake-rate bug** — CoS still disabled. Platform team work.
- **MT5 tester report.htm parser drift across builds** — G4 patterns validated against build 5833; future builds may shift the HTML shape. CTO refines on each new MT5 install.
- **Codex provider-side billing visibility** — `spentMonthlyCents` doesn't reflect Codex actual spend; CoS tracks via run-rate proxy until provider API integration lands.

## Cross-references

- DL-046 — anti-theater principle (the umbrella)
- DL-051 — issue-creation gate (companion)
- DL-053 — CEO operating contract (companion)
- DL-054 — anti-theater pass criteria (this incident's mode 2 corrective)
- DL-055 — DevOps token-burn watch (mode 1 corrective, data side)
- DL-056 — CoS hire (mode 1 corrective, decision side; mode 4 self-aware)
- DL-057 — Research-resume on baseline-queue-empty (mode 5 corrective; perpetual flow)
- `docs/ops/QUA-684_D2_BAR_COMPILATION_AUDIT_2026-05-01.md` — mode 3 evidence
- `docs/ops/QUA-662_PHANTOM_PASS_AUDIT_2026-05-01.md` — mode 2 evidence
- `docs/ops/BLOCKED_QUEUE_TRIAGE_2026-05-01.md` — mode 6 + general triage
- `docs/ops/TUESDAY_RESTART_RUNBOOK_2026-05-05.md` — single-sheet remediation plan
- `feedback_act_directly_not_comment_route.md` — mode 8 memory
- `feedback_paperclip_agent_config_patch_works.md` — companion memory

— Board Advisor 2026-05-01.
