# Claude Orchestration Status 2026-05-23T16:45Z

Status: IDLE — no IN_PROGRESS claude tasks; escalations carried forward + new findings

## Router outcome

- `agent_router.py status` — 2 Gemini tasks IN_PROGRESS, 3 TODO (unroutable), 0 Claude tasks.
- `agent_router.py run --min-ready-strategy-cards 5 --max-routes 5` — research replenishment
  still frozen (`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`); 0 ready
  approved cards (2175 approved, all blocked — +3 since 1630Z cycle). One TODO task
  cannot route (`no_available_agent`); all 3 TODO tasks require `source_discovery` (Gemini-only).
- `agent_router.py list-tasks --agent claude` — empty; no tasks to process.

## Health snapshot

`farmctl health` overall: **FAIL** (2 FAILs, 1 WARN, same structure as 1630Z)

| Check | Status | Detail |
|---|---|---|
| `codex_review_fail_rate_1h` | **FAIL** | 2/14 system-class FAILs across 2 EAs |
| `p_pass_stagnation` | **FAIL** | 0 Q03+ PASS verdicts in 12h |
| `unenqueued_eas_count` | WARN | 9 EAs without Q02 work_items |
| `mt5_worker_saturation` | OK | 10/10 workers alive |
| `mt5_dispatch_idle` | OK | 2 pending (low queue) |
| `disk_free_gb` | OK | 154.4 GB free |

## Deltas since 1630Z cycle

### KillSwitch defect blast radius now confirmed: 10+ EAs permanently failed

All EAs below hit `build_check.result=FAIL` due to `duplicate g_qm_ks_initialized in
QM_KillSwitchKS.mqh / QM_KillSwitch.mqh`. All 3 attempts exhausted → status: `failed`,
`final_failure: permanent_blocked_retries_exhausted`. These are hard-stopped until Codex
renames the global in `QM_KillSwitchKS.mqh`.

| EA | Slug |
|---|---|
| QM5_10000 | ff-tasayc-cci-breakout |
| QM5_10001 | ff-static-fib-open |
| QM5_10002 | ff-sisyphus-2ma-rsi-d1 |
| QM5_10003 | ff-xaron-morning-breakout |
| QM5_10004 | ff-razor-h1-5pip |
| QM5_10015 | ff-bb-stoch-h1 |
| QM5_10017 | ff-stoch-ema50-h4 |
| QM5_10018 | ff-bb-shadow-reversal-h1 |
| QM5_10020 | rw-spx-overnight |
| QM5_10024 | rw-fx-comm-basket |

**Note**: QM5_10020 also has active Q02 work_items running (different build version). The
permanently-failed entry is a subsequent build attempt. The Q02 runs are from an earlier
compiled version.

**Unblock action**: Codex must rename `g_qm_ks_initialized` to `g_qm_ks_initialized_ks`
(or similar) in `framework/include/QM_KillSwitchKS.mqh`, commit, and rebuild all 10.

### New: run_smoke framework error → RISK_PERCENT pattern in ea_review

Two ea_review tasks got REJECT_REWORK this cycle with compound issues:

**QM5_10039** (`ff-hline-sma50-h1`) — `ea_review` REJECT_REWORK
- Smoke deferred: `framework_error run_smoke Resolve-DispatchTerminal requires -SetFilePath when -TargetTerminal='any'`
- RISK_PERCENT default is 0.0 with no live-deploy comment at mq5:43
- Rework directives: fix smoke invocation with explicit setfile; add RISK_PERCENT=0.5 default
  or adjacent live comment

**QM5_10044** (`ff-vr-gap-fade`) — `ea_review` REJECT_REWORK
- Same smoke deferral error
- RISK_PERCENT default is 0.0 with no live-deploy comment at mq5:46
- Codex_review for this EA independently PASSED (framework_corset, magic_registry,
  forbidden_grep all PASS); the rejection is from the separate ea_review check

**Pattern**: `Resolve-DispatchTerminal requires -SetFilePath when -Terminal any` is appearing
in every smoke deferral. This is a systemic run_smoke bug — the build smoke invocation
does not pass `-SetFilePath` when dispatching with `-Terminal any`. All affected EAs get
`smoke_result: deferred_p2_smoke`, which then causes ea_review to reject. Codex needs an
OPS_FIX for the `run_smoke` / smoke dispatch logic.

### New: ea_review pending for QM5_10043

`tasks` table: `ea_review` for QM5_10043 (`ff-50macd-4h`) status=`pending`. Codex_review
PASSED (framework_corset, magic_registry, forbidden_grep PASS; smoke_sanity UNKNOWN due to
smoke deferral). Pump will dispatch this ea_review when ready.

### New: codex_review pending for QM5_10035

`tasks` table: `codex_review` for QM5_10035 (`rw-stat-arb`) status=`pending`. Built
successfully (compiled, smoke deferred). Includes flag: symbol `GER40.DWX` in card not in
`dwx_symbol_matrix.csv`; Codex substituted `GDAXI.DWX`. Review pending.

### QM5_10025 (rw-fx-broad-pairs) — distinct failure

This EA failed with 55 compile errors unrelated to KillSwitch:
- Missing include `QM_TM_Grid.mqh`
- Invalid static array initializers in the mq5 file
- Requires Codex investigation — likely a Codex scaffolding error (attempted to use
  grid-trade module that doesn't exist in V5 framework). Permanently failed (attempt 3/3).

### QM5_1056 Q02 PASSes — pipeline positive signal

QM5_1056 (`moskowitz-tsmom-multiasset`) has completed Q02 for 8 AUDUSD.DWX setfiles:
- PASS: AUDUSD.DWX base + synth_000 + synth_001 + synth_002 (4 passes)
- FAIL: AUDJPY.DWX, AUDCAD.DWX, AUDCHF.DWX (strategy-level, expected cross-sectional washout)
- INFRA_FAIL: AUDNZD.DWX (isolated; may be a tick data gap on that pair)

The 4 AUDUSD PASS setfiles are the first Q02 PASSes in the current cycle batch. The factory
should advance AUDUSD variants to Q03 (walk-forward). No Q03 work_items yet — pump or manual
enqueue needed. p_pass_stagnation FAIL is expected until Q03+ items complete.

**QM5_1099** (`dax-weekly-donchian50-breakout`) — Q02 results this cycle:
- Multiple FAIL verdicts across AUD cross-pairs (cross-strategy, expected universe mismatch)
- INFRA_FAILs on AUDUSD, AUDNZD, CADCHF, CADJPY W1 — W1 data gaps likely
- No PASSes recorded; strategy may not have an edge in AUD crosses (universe mismatch pattern)

### QM5_10260 queue state

`farmctl work-items --ea QM5_10260` → 0 items. Unchanged from 1630Z cycle. The
`cieslak-fomc-cycle-idx` TIMEOUT washout (37 symbols, 1800s each) has not been re-enqueued.
Awaiting OWNER decision: performance rework task for Codex, or formal close.

## Active Q02 backtests (running at time of this cycle)

| EA | Symbol | Status |
|---|---|---|
| QM5_10019 | EURUSD.DWX M5, GBPUSD.DWX M5, USDJPY.DWX M5 | active |
| QM5_10020 | SP500.DWX D1, WS30.DWX D1, NDX.DWX D1 | active |
| QM5_10021 | AUDUSD.DWX D1 | active |

## Persistent escalations (from 1630Z cycle, unchanged)

1. **Merge `agents/board-advisor` → `main`** — schema fix 357f93bf unlocks 2175 blocked cards.
2. **KillSwitch rename in QM_KillSwitchKS.mqh** — now blocks 10 EAs (table above).
3. **run_smoke dispatch bug** — `Resolve-DispatchTerminal requires -SetFilePath when -Terminal any`
   → systemic ea_review failures. OPS_FIX needed.
4. **RISK_PERCENT default** — Codex must add default 0.5 or live comment to QM5_10039, QM5_10044.
5. **QM5_10025** — Codex scaffolding error (QM_TM_Grid.mqh missing); needs rebuild from scratch.
6. **QM5_10717 + QM5_10718** — Edge Lab basket EAs; INFRA_FAIL Q02 (EURUSD D1); cause unknown.
7. **QM5_10260** — OWNER decision required (performance rework or close).
8. **QM5_1056 Q03 advance** — 4 AUDUSD PASSes ready for walk-forward; pump should enqueue.
