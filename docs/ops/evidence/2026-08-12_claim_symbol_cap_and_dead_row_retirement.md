# Claim Same-Symbol Cap + Dead-Row Retirement — 2026-08-12

Operator: Claude. Trigger: OWNER "Es laufen nur 2 MT5? Heute nur 148 Backtests?
Codex trotzdem leer?" (interactive, 2026-08-12 ~15:30Z). Ratification: OWNER
"Go, bau die Änderung und räum die toten Rows ab" + XTI reroute directive.

## Diagnosis: structural 2-slot degeneration

All 8 idle workers polled healthily (log mtimes current) and declined with
`no_pending_claimable, history_skipped: 71`. Offline replication of the claim
loop (same filters, same registry) over the 1,031 rows returned by
`pending_claim_order_sql()` reproduced the worker logs exactly and decomposed
the queue for T1:

| filter | rows | mechanism |
|---|---|---|
| `symbol_active` | 504 | every XAUUSD.DWX row blocked by ONE active XAUUSD run (T9, Q08) — fleet-wide one-active-per-symbol rule |
| multisym serialization | 434 (103 prio + 331 recovery) | max ONE basket farm-wide (OWNER 2026-06-24 RAM rule) — T4 running one |
| no history | 71 | 58 W1/MN1 rows (dead class) + 26 XBRUSD.DWX rows (Brent archive never imported, zero registry entries) + overlap variance per pass |
| avoid_terminals | 22 | legitimate |
| **claimable** | **0** | — |

Claim ledger 2026-08-12: strictly serialized claims 5–10 min apart, all class
`priority`, zero recovery — recovery gate itself was OPEN
(`recovery_claim_allowed=True`, occupancy escape active at 2 < 5); the
recovery rows were all symbol/multisym-blocked. Day throughput ≈155
completions/15h ≈ 10/h vs ≥30/h fleet capacity.

Correction to the morning report: recovery backlog is NOT drained to 34 —
`is_recovery_payload` classifies 848 of 1,031 pending as recovery class. The
morning query used `attempt_count>0`, the wrong heuristic.

## Change: CLAIM_SYMBOL_ACTIVE_CAP=4 (commit b38ecf424)

Origin of the old rule: `docs/ops/INDEX_SYMBOL_CRASH_DIAGNOSIS_2026-05-18.md` —
five simultaneous items of ONE (ea_id, symbol) (QM5_1056/NDX) crashed the
fleet in the SHARED `Bases\Custom` era; mitigation serialized dispatch to one
active item per symbol fleet-wide (commits 40557027c, 4af8fbf26).

Variant-A isolation (live 2026-08-10) gives each terminal a physical,
content-verified private Custom store with copy-on-claim privatization — the
shared-history hazard behind the crash class is gone. New contract, applied to
all three claimants (terminal_worker claim loop, terminal_worker targeted
claim, farmctl dispatch secondary claimant):

1. **Duplicate (ea_id, symbol) stays hard-serialized** — the literal
   2026-05-18 crash shape never runs twice concurrently
   (`deferred_symbol_lock` preserved).
2. **Cross-EA same-symbol work runs up to `CLAIM_SYMBOL_ACTIVE_CAP = 4`**
   (new `deferred_symbol_cap` action beyond the cap). The cap bounds
   first-privatization copy I/O and tick-cache herds; it is a farmctl
   constant, single source for both claimants.

Tests: 3 new claim-loop tests (parallel-below-cap, block-at-cap, duplicate
pair), 2 new dispatch tests (cap + duplicate on the real dispatch path),
3 WS-A tests re-seeded to construct ineligible frontiers via the duplicate
guard (contract surgery, same intent). Suites green:
`test_ultracode_wsa_claim` + `test_index_symbol_dispatch_serialization` +
`test_terminal_worker_atomic_claim` = 100 passed;
`test_basket_work_items` + `test_terminal_worker_adoption` = 20 passed.

**Activation**: farmctl dispatch lane (fresh pump processes) picks the cap up
immediately; the resident workers require an OFF/ON window (no self-reload).
Multisym basket serialization (1 farm-wide) is deliberately unchanged.

## Dead-row retirement (executed 15:58Z)

DB backup: `D:\QM\strategy_farm\state\backups\farm_state_before_dead_row_retire_20260812T155807Z.sqlite`.

- **58 W1/MN1 rows → status=failed, verdict=RETIRE** (`verdict_reason`:
  W1/MN1 untestable on DWX custom symbols — 0 bars in tester; doctrine
  2026-08-11: weekly cards are D1-native ×5-rescale). EAs: QM5_10305,
  QM5_1079, QM5_1099 (24-symbol W1 FX sweep), QM5_11070, QM5_11500, QM5_1173,
  QM5_12376 et al. Optional follow-up (not ticketed): D1-native rebuilds where
  a card merits it.
- **26 XBRUSD.DWX rows → status=failed, verdict=RETIRE** with
  `rerouted_to_symbol=XTIUSD.DWX` stamped (Brent archive never imported —
  zero `(XBRUSD.DWX, *)` entries in the DWX history registry; XTIUSD has full
  2017–2025 coverage on T1–T10). Per-row `events` entries record the OWNER
  authorization.
- Pending queue 1,038 → 951.

## XTI reroute ticket

Router task `9ad6d9c0-d67b-4092-80e6-4df2f826eb73` (build_ea, prio 70, TODO):
23 Brent EAs get an XTIUSD.DWX D1 setfile (gen_setfile.ps1) + fresh Q02
enqueue following the QM5_20288 WTI pattern. QM5_1188/1189/1192 excluded
(existing XTIUSD INFRA_FAIL graveyard rows; graveyard triage owns them).
Brent-specific seasonality cards run on WTI as oil proxies — Q02 judges.

## Quota context (side answer)

Codex 93% used at 23.4% week elapsed — hard ceiling (≥90%), governor `hold`,
reset 2026-08-18T00:03Z. Burn driver: 5×-era overnight volume (WTI cohort,
fx-carry-unwind research, 15-min lanes). Backtests unaffected (never
throttled). Claude 53% at 76% elapsed, resets 2026-08-13T22:00Z.
