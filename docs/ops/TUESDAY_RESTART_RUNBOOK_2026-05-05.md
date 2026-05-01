# Tuesday Restart Runbook (2026-05-05 ~07:30 W. Europe)

**Author:** Board Advisor 2026-05-01 — written during the Codex outage as a single-sheet for CEO to follow Tuesday morning.
**Goal:** turn the company back on cleanly post-Codex-quota-restore + execute the first real DL-054-gated V5 baseline.

## Context (what happened over the weekend)

Codex token quota exhausted Friday 2026-05-01 ~12:00 UTC; recovery scheduled for Tue 07:30 W. Europe. While Codex was offline, Board Advisor + OWNER:

- Compiled M1 bar history for the 33 missing-history `.DWX` symbols (v2 MQL5 script in `framework/scripts/mt5/Compile_Custom_Bars_QM_v2.mq5`; produced 53M bars, 35/35 OK).
- Propagated T1 → T2..T5 byte-identical (3.8 GB each).
- Invalidated the QUA-662 phantom-PASS matrix; codified DL-054 anti-theater pass criteria + `framework/registry/tester_defaults.json` (100k deposit / 1000 fixed risk).
- Hired Chief-of-Staff (`38f933cd-...`, DL-056), then disabled its heartbeat after wake-rate spam (wake-on-demand only).
- PATCHed Doc-KM and QB Opus → Sonnet (cost reduction; matches laptop pattern).
- Disabled heartbeats on all 4 Codex agents (CTO / DevOps / Development / Pipeline-Op) — they would otherwise fire-and-fail every cycle.
- Filed DL-055 (token-burn watch via DevOps + QUA-527, CEO's choice) and DL-056 (CoS hire layered on top).
- Filed DL-057 amending DL-044 — Research resumes when baseline queue is empty, not when first EA reaches P7.
- Drafted `framework/scripts/dl054_gates.py` (the 5-gate enforcement library, smoke-tested) and `framework/scripts/dl054_integration.md` (splice plan for Pipeline-Op launcher).

This runbook turns the company back on in the right order.

---

## Step 0 — Confirm Codex restored (1 min)

```
codex exec --model gpt-5.3-codex "echo ok"
```

Expected: prints `ok`. If you get a quota error, wait until 07:30 W. Europe local. If still failing past 08:00, escalate to OWNER.

## Step 1 — Verify gate library is healthy (2 min)

```
python C:\QM\repo\framework\scripts\dl054_gates.py
```

Expected output: `canonical_symbols: 36 found` followed by 36 `.DWX` names AND `tester_defaults: { ... initial_deposit: 100000 ... }`. If the canonical-symbol count is wrong or tester_defaults fails to load, **stop** — Pipeline-Op won't be able to gate runs without these. Investigate `framework/scripts/dl054_gates.py` and `framework/registry/tester_defaults.json`.

## Step 2 — Verify Codex model SKUs (per QUA-684 comment 92a65482) (3 min)

For each candidate model, run a one-line probe:

```
codex exec --model gpt-5-codex "echo ok"
codex exec --model gpt-5-codex-mini "echo ok"
codex exec --model gpt-5.3-codex "echo ok"
```

Note which print `ok`. Use only verified SKUs in Step 3.

## Step 3 — PATCH model + re-enable heartbeats on the 4 Codex agents (5 min)

For agents whose downgrade SKU validated in Step 2, do **two** PATCHes per agent: `adapterConfig.model` then `runtimeConfig.heartbeat`. If a downgrade SKU was rejected, fall back to `gpt-5.3-codex` for that agent (no harm).

Per QUA-684 comment `92a65482`:

| Agent | UUID | Recommended model | Notes |
|---|---|---|---|
| CTO | `241ccf3c-ab68-40d6-b8eb-e03917795878` | KEEP `gpt-5.3-codex` | strategic code review |
| Development | `ebefc3a6-4a11-43a7-bd5d-c0baf50eb1f9` | KEEP `gpt-5.3-codex` | heavy MQL5 code-gen |
| DevOps | `86015301-1a40-4216-9ded-398f09f02d26` | TRY `gpt-5-codex` | infra scripts |
| Pipeline-Op | `46fc11e5-7fc2-43f4-9a34-bde29e5dee3b` | TRY `gpt-5-codex-mini` | orchestration |

Heartbeat re-enable PATCH (apply to each Codex agent **except DevOps** — DevOps stays paused per DL-046 churn — see Step 4):

```bash
curl -X PATCH -H 'Content-Type: application/json' \
  -d '{"runtimeConfig":{"heartbeat":{"enabled":true,"cooldownSec":60,"intervalSec":1800,"wakeOnDemand":true,"maxConcurrentRuns":5}}}' \
  http://127.0.0.1:3100/api/agents/<UUID>
```

(Same for Pipeline-Op + CTO + Development. DevOps unblocks separately in Step 4.)

## Step 4 — Fix DevOps QUA-671 churn before unpausing DevOps (10 min)

DevOps was paused Friday because of a 114-commits-per-hour keepalive loop on QUA-671 (DL-046 violation). Root cause was a signal-file refresh that didn't gate on semantic delta. Before unpausing DevOps:

1. Find the script writing `docs/ops/QUA-671_BLOCKED_HEARTBEAT_*` files. Likely candidates:
   - `infra/scripts/Run-QUA95BlockerRefresh.ps1` (named QUA-95 but may have been generalized)
   - One of the (now-disabled) scheduled tasks `QM_AggregatorState_1min`, `QM_QUA95_BlockerRefresh`, `QM_RuntimeHealthScan_15min`, `QM_InfraHealthCheck_5min`
2. Patch the refresh logic to: `if status==blocked AND no_new_input_since_last_signal: SKIP_REWRITE`. Pseudo-pattern:
   ```python
   if last_signal_content_hash == current_signal_content_hash:
       return  # no semantic delta → don't write/commit
   ```
3. **Then** re-enable the previously-disabled scheduled tasks one at a time, watching commit cadence after each.
4. Then unpause DevOps via Paperclip UI (OWNER-class operation per `feedback_agent_pause_unpause_owner_only.md`).

CTO + DevOps own this. Quality-Tech reviews the patch before re-enable.

## Step 5 — Wire DL-054 gates into Pipeline-Op launcher (45 min)

CTO follows `framework/scripts/dl054_integration.md`. Splice points:

1. **Pre-launch gates in `pipeline_dispatcher.py`** — call `apply_pre_launch_gates(...)` before any tester launch. On `verdict=INVALID`, write the row to `report.csv` and skip the launch.
2. **Post-launch gates in per-phase runners (`p35_csr_runner.py`, `p5_stress_runner.py`, etc.)** — call `apply_post_launch_gates(...)` after tester completes, before writing PASS verdict. Use journal path under `D:/QM/mt5/<terminal>/Tester/logs/<date>.log`.
3. **Extend report.csv schema** with `invalidation_reason` and `evidence` columns.

Acceptance: deliberately-failing test runs land `verdict=INVALID` with the right `invalidation_reason`.

## Step 6 — Re-run QM5_1003 P2 baseline (clean — first real V5 baseline) (1-3 hr depending on tick volume)

Pipeline-Op dispatches the matrix. Inputs:

- EA: `QM5_1003` (davey-baseline-3bar, SRC01_S03)
- Symbols: 36 canonical from `framework/scripts/dl054_gates.py` `canonical_symbols_from_filesystem()` — DO NOT use `.scratch/qua662_done_symbols.txt` from the previous broken run; rebuild from filesystem.
- Window: per pipeline spec (DEV 2017-2022 then HOLDOUT 2023-2024 typically — confirm in PIPELINE_PHASE_SPEC.md § P2)
- Setfile: `RISK_FIXED` per DL-038 Rule 7
- Output: `D:/QM/reports/pipeline/QM5_1003/P2_clean_<TIMESTAMP>/`

After matrix completes, **all rows in `report.csv` MUST be either `PASS` or `INVALID` with `invalidation_reason`** — never bare `FAIL` from no-data exits, never silent PASS from theater.

QT reviews the matrix per DL-054 gate-of-record. CEO reads the verdict. If clean PASS rate is ≥50%, advance to P3 (parameter sweep). If lower, diagnose.

## Step 6.5 — Install DL-057 Research auto-wake pulse (5 min)

Installs `framework/scripts/dl057_research_auto_wake.py` as a 15-min scheduled task. The pulse polls Paperclip API for the three DL-057 pause conditions (P0/P1/P2 active queue, matrix mid-run, G0 review unresolved) and posts a wake comment on Research's rolling tracker (QUA-711) when all three flip FALSE. Means CEO does NOT have to remember to wake Research — the company self-continues per OWNER's "doesn't stop" directive.

Install once:

```powershell
schtasks /create /tn "QM_DL057_Research_AutoWake_15min" /sc minute /mo 15 /tr "python C:\QM\repo\framework\scripts\dl057_research_auto_wake.py" /ru Administrator /rl highest /f
```

Verify:

```powershell
schtasks /query /tn "QM_DL057_Research_AutoWake_15min"
```

Pulse output lands at `D:/QM/reports/ops/dl057_research_pulse.log` and state at `D:/QM/reports/ops/dl057_research_pulse_state.json`. 1-hour cooldown between wakes prevents spam.

**Important:** Pipeline-Op should prune zombie entries from `D:/QM/Reports/pipeline/dispatch_state.json` Tuesday morning (15 zombie rows from invalidated QUA-662 loop). The pulse script auto-ignores entries older than 12h, but a clean dispatch_state is best-practice.

## Step 7 — Wake Research with first batch (per DL-057) (5 min — comment-only)

Once Step 6 is in flight (P2 dispatched on T1-T5, queue is no longer empty — but Step 6 takes hours), Research stays paused. Once the matrix completes AND no other EAs are queued for build/baseline, Research resumes.

For Tuesday morning, the **right move is NOT to wake Research yet** — wait until P2 closes. Per DL-057 R-057-1, baseline queue empty is the trigger.

When that happens, post a comment on Research's rolling tracker (UUID `7aef7a17-...`) with the wake brief:

> Resume per DL-057. Extract ≤3 cards from the current SRC (continuing whichever SRC has open cards). Run dedup against `framework/registry/ea_id_registry.csv` + `framework/registry/magic_numbers.csv` + existing strategy fingerprints. Hand to QB for G0 review per DL-030 Class 2.

## Step 8 — Confirm CoS heartbeat handling (1 min)

CoS (`38f933cd-...`) currently has `heartbeat.enabled=false` to prevent wake-rate spam (Friday harness fired it ~45s when 1h was scheduled). Two options:

- (a) Leave disabled, wake CoS via comment on QUA-699 weekly (Monday 08:30 W. Europe per its prompt).
- (b) Re-enable but lower interval floor — set `intervalSec: 7200` (2h) and hope harness respects it. Risk of re-spam.

Recommended: leave disabled until Paperclip platform team fixes the harness wake-rate bug (`feedback_paperclip_agent_config_patch_works.md` notes this is an edit-friendly field — flip when harness is fixed).

## Step 9 — Status report to OWNER (5 min)

Post a one-screen summary on `QUA-684` (still in_progress) with:
- Codex restore confirmed ✓
- 4 Codex agents PATCHed + heartbeat re-enabled
- DevOps QUA-671 patched + unpaused (or "still blocked, fix in flight")
- DL-054 gates wired (with commit hash)
- QM5_1003 P2 clean baseline kicked off (run path)
- ETA for first PASS verdict on report.csv

Then exit. The Tuesday restart is done.

---

## Quick troubleshooting

| Symptom | Likely cause | Action |
|---|---|---|
| `dl054_gates.py` returns 0 canonical symbols | hourly_*.log rotated to a stub today | Check `D:/QM/mt5/T1/bases/Custom/history/` exists; library falls back to filesystem |
| `gpt-5-codex` rejected at Codex CLI | SKU naming differs by version | Fall back to `gpt-5.3-codex` for that agent |
| Pipeline-Op fires but no report.csv | DL-054 gate rejected pre-launch | Read `invalidation_reason` in row; usually G1 (history coverage) or G5 (canonical name) |
| QUA-671 churn returns | Refresh script wasn't fully patched | Re-disable scheduled task; CTO investigates the missed code path |
| CoS spams comments | Heartbeat harness wake-rate bug | PATCH `runtimeConfig.heartbeat.enabled=false` again |

## Cross-references

- `framework/scripts/dl054_gates.py` — gate library
- `framework/scripts/dl054_integration.md` — splice plan
- `framework/registry/tester_defaults.json` — G2 inputs
- `decisions/DL-054_anti_theater_pass_criteria.md` — gate spec
- `decisions/DL-055_token_burn_watch_qua527_unblock.md` — CEO's option (b)
- `decisions/DL-056_chief_of_staff_os_controller_hire.md` — CoS scope
- `decisions/DL-057_research_resume_on_empty_baseline_queue.md` — Research wake gate
- QUA-684 comment `92a65482` — Codex model recommendation
- QUA-699 — CoS rolling tracker

— Board Advisor 2026-05-01.
