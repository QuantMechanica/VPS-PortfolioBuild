# Velocity book — programme start 2026-09-20 (Fable)

**Authority:** OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917; OWNER 2026-09-20 ("solange Kapazitäten irgendwo
vorhanden sind, kannst du die Priorität auch jetzt schon auf das Velocity-Buch legen"). Goal KPI: `FTMO_NET_CASH_REALIZED`
via a book whose first-passage time to the FTMO target is measured in weeks, not years (`docs/ftmo/FTMO_PORTFOLIO_GAP_CURRENT.md`
§2: ≈100 USD/bd of drift at ≤2.5 % book risk ⇒ median ≤ 90 business days).

## 1. Measured velocity of the existing inventory (0 factory hours)

Per-stream statistics from the frozen W38 snapshot (26 qualified streams, Q08 trade files, RISK_FIXED 1000 = 1 %/trade),
`velocity_stats.json`; and a Q02 summary screen over every intraday (M1–H1) Q02-PASS pair with surviving evidence
(`q02_velocity_screen.json`, 162 pairs):

| stream | trades/bd | E[R] | R/bd | hold h | overnight | note |
|---|---|---|---|---|---|---|
| 13213 USDJPY H1 (Balke range breakout) | 0.74 | +0.064 | 0.048 | 7.2 | 0 % | fastest measured stream, in D2g6 |
| 10706 GBPUSD H1 | 0.17 | +0.192 | 0.032 | 7.4 | 46 % | in D2g6 |
| 10700 XAUUSD H1 | 0.18 | +0.165 | 0.029 | 19.7 | 58 % | in D2g6 |
| 11660 NDX H4 | 0.73 | +0.022 | 0.016 | 12.0 | 40 % | `.DWX` literal gate, not deployable |
| 10423 XAUUSD H1 (Q02 screen) | 0.82 | +0.086 | 0.071 | – | – | Q05 FAIL dd 41 % at 1 %/trade |
| 11690 XAUUSD H1 (Q02 screen) | 1.84 | +0.028 | 0.052 | – | – | Q05 FAIL dd 59 % |
| 11263 XAUUSD M1 (Q02 screen) | 0.22 | +0.175 | 0.039 | – | – | Q02–Q07 PASS, Q08 INVALID (sealed-calendar window) |

**Finding:** no measured stream exceeds ≈0.07 R/bd; the whole non-duplicate intraday inventory sums to ≈0.16 R/bd (≈40 USD/bd
at 0.25 %/trade). The Velocity book therefore needs new intraday candidates — 6–8 uncorrelated sleeves at ≥0.5 trades/bd and
≥+0.10R each — and the fastest way to find them is breadth: many cheap Q02 canaries on M5–H1, ranked by R/bd.

## 2. Intake waves executed today

| wave | what | result |
|---|---|---|
| 1 | 4 held COMPILE_EA rows released (39002, 39004, 38001, 41355) | 3× COMPILE_OK; Q02 canaries: 39002 EURUSD M15 PASS-setup but −99.9k / PF 0.83 (economic REJECT), 39004 EURUSD M5 FAIL (19 trades), 38001 EURUSD M5 running |
| 2 | `FABLE-DEC-VELOCITY-INTAKE-20260920` document-bound force rebuild of 6 EAs whose 26.08. COMPILE_OK binary vanished (janitor revert class) | 11516 M15, 11299 M5 COMPILE_OK; 11291/11292/11496/11518 first refused by STALE workers (see §3) and re-enqueued |
| 3 | 83 built-but-never-measured intraday cards: `target_symbols` amendment (registry slot order / OWNER 2026-09-01 default universe; backups in `card_backups/`), 3 governed magic allocations (11375/11380/20175), force-rebuild list extended to 43 EAs, compile tranches of 10 | first tranche: 16 of 18 fail `build_check` with `EA_Q08_MAE_HOOK_MISSING` & co. (`compile_fail_table_wave3.json`) → Codex modernisation ticket 3c44384d; COMPILE_OK so far: 11537 H1 (canary queued) |

Session tool: `tools/strategy_farm/session_tools/velocity_intake_pump_0920.py` (commit receipted binaries → canaries for
COMPILE_OK rows → next tranche → status table).

## 3. Structural defects found and fixed today (all committed, tests green)

1. **Review entry gate blocked by bookkeeping rows** (`review_entry_gate.py`): 194 `ARCHIVED (…)` and 226 `PARK (…)` rows in
   state FAILED/BLOCKED were read as review fails and refused Q02 intake for EAs with an APPROVED build (QM5_38001, QM5_11537).
   Fix `63531b635b` + `8ea46abf17`: archived/parked rows are skipped as if absent; genuine FAIL/BLOCKED rows still block.
2. **Worktree janitor and first compiles**: a first governed compile leaves the binary untracked (`??`) — not covered by
   yesterday's receipted-ex5 rule → `65dbf8a704`. The receipt must also bind `mq5_sha256` (guard parity; QM5_12351 case) →
   `e7bf098f5e`. 28 receipted binaries committed in `c8be099935`.
3. **Stale-worker class again**: workers started 15:25Z carried the pre-registration `compile_work_items` module and refused
   every force rebuild with `CANDIDATE_RECHECK_REFUSED`; staggered restart (batches 4/5/1 via the SYSTEM watchdog task) at
   16:51–16:56Z, 16 rows re-enqueued.
4. **Legacy rework loop** rewrote QM5_41154/41155 sources a third time (16:03Z) and blocked the build lane; legacy build task
   baf614cf parked alongside e8e61fe1, patch archived, sources restored (`a7bb2925cc`).

## 4. Commissioned (Codex, weekly budget line)

| ticket | priority | scope |
|---|---|---|
| 3c44384d | 80 | modernise the build_check failures (MAE hook, trade-request init, raw-series calls) under the generic repair registry, compile, canary |
| de9d8271 | 78 | allocator refusals: non-active magic history (8 EAs), slug mismatches (9165, 11467), registry-not-active (10 EAs), 12351 SP500 row |
| 690be249 | 74 | QM5_41141 GBPUSD M15 live-card-defaults guardrail repair → Q02 |
| a0780fc3 | 72 | §68A analysis: Q05 drawdown ceiling vs high-density streams (density-normalised / R-denominated v2 proposal, FP/FN table; no gate change) |
| 145468a8 | 70 | prescreen-v2 independent critique re-issued on the Codex seat (0d2b234d superseded) |

## 5. Next

- Keep the pump cycling (canary results feed `q02_velocity_screen.py` ranking; survivors get `mark-priority-track`).
- 11263 XAUUSD M1 (best measured intraday E[R]): diagnose `DSR_V2_TRADE_OUTSIDE_SEALED_CALENDAR` — data-window vs sealed
  cohort mismatch, not economics.
- Fable-originated Velocity hypotheses (QM-RESEARCH artifacts) on the profile that measured best: session-range breakouts
  with 0 % overnight (13213 template) on JPY crosses / gold / GDAXI, M15–H1 — cross-vendor critic = Codex.
