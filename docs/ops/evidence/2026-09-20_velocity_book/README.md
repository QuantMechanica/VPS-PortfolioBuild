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

### 1b. Census velocity frontier (4,752 measured configurations, 36 programmes, 7 years) — `census_velocity_frontier.json`

Aggregating every measured OPT_CENSUS / WINSWEEP cell per configuration: the best cross-year configuration of any
programme reaches **0.075 R/bd** (41398 USDJPY window sweep `s1_l4_x20`, 0.73 trades/bd, +0.103R); the incumbent
baseline of the same EA is 0.040. No programme exceeds ≈0.08 R/bd in any configuration.

### 1c. Holdout of the frontier (select 2019–2022, validate 2023–2025) — `census_frontier_holdout.json`

| programme | best arm (selection R/bd) | same arm on validation | baseline on validation |
|---|---|---|---|
| 13213 USDJPY | sell_081 (0.067) | 0.029 | 0.034 |
| 41398 USDJPY winsweep | s1_l4_x20 (0.108) | 0.032 | – |
| 41405 USDJPY winsweep | c48 (0.081) | 0.056 | – |
| 10706 GBPUSD | buy_052 (0.061) | 0.039 | 0.033 |
| 10700 XAUUSD | sell_057 (0.026) | 0.062 | 0.062 |

**Finding:** in-sample winners do not beat the baseline out of sample; the parameter/filter space of the existing EAs
holds no reliable velocity uplift (the conservative DL-089 `NO_FILTER_CHANGE` verdicts are vindicated). The OOS ceiling
per sleeve is ≈0.03–0.06 R/bd. Consequence: **the Velocity book is a breadth problem — more sleeves of the fastest
measured profile on more instruments — not an optimisation problem.**

## 2b. Velocity lineage QM5_41484 `balke-range-breakout-fx-fanout` (started 19:2xZ)

Byte-identical copy of the qualified incumbent QM5_13213 (Balke GMT+3 session-range breakout, 0 % overnight) as a NEW
build identity with ten FX magic slots (USDJPY control + EURJPY, GBPJPY, AUDJPY, CHFJPY, EURUSD, GBPUSD, USDCHF, USDCAD,
AUDUSD). Card `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41484_balke-range-breakout-fx-fanout.md`
(falsification: <60 trades/yr or < +0.03R or PF < 1.05 per symbol retires the symbol; lineage retired if fewer than two
symbols besides USDJPY survive Q04). Registry rows + resolver `02b5428b42`, COMPILE_OK 34fb5dd8 (ex5 bdf961c2…) committed
`dbb24e8ec9`, first canary AUDUSD H1 `ff45d4ae` active 19:35Z; the remaining nine symbols seed automatically after it.

## 2c. Canary results 16:30–19:35Z (Q02 2018-07..2022-12, RISK_FIXED 1000)

24 canaries measured, **1 net-positive**: QM5_11442 burke-frd-fgd-daily-pump M5 AUDUSD (+11.5k, PF 1.27, 142 trades,
0.12 trades/bd → 0.010 R/bd: real but slow). Everything else net-negative (PF 0.5–0.9). The legacy TradingView /
ForexFactory intraday backlog is not a velocity source; Codex ticket 3c44384d was throttled accordingly.

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

### Finds log (cron watch)

- 20:23Z — QM5_11442 burke-frd-fgd-daily-pump M5: AUDUSD +11.5k / PF 1.27 / 0.12 trades/bd (R/bd +0.010) and GBPUSD +8.1k /
  PF 1.12 / 0.10 trades/bd (R/bd +0.007). Real but slow; Q04 AUDUSD row 03934079 priority-tracked.
- 20:23Z — QM5_41484 fan-out interim (6 of 9 new symbols measured, Q02 2018-07..2022-12): AUDJPY +0.005R (flat),
  AUDUSD −0.003R, GBPUSD −0.015R, CHFJPY −0.097R, EURUSD −0.082R, USDCAD −0.088R vs parent USDJPY +0.053R / PF 1.12.
  The Balke 03–06 GMT+3 window does not carry over to non-JPY majors; EURJPY / GBPJPY / USDCHF and the USDJPY control
  still running.
- 21:23Z — QM5_41484 fan-out COMPLETE (10/10): USDJPY control reproduced the parent byte-exactly (+46,637 / PF 1.12 /
  0.76 trades/bd — validates the new build identity), the nine other symbols are flat to negative (AUDJPY +0.005R,
  GBPJPY −0.001R, AUDUSD −0.003R, GBPUSD −0.015R, EURJPY −0.024R, EURUSD −0.082R, USDCHF −0.087R, USDCAD −0.088R,
  CHFJPY −0.097R). Card falsification rule met (fewer than two survivors besides USDJPY) → **lineage RETIRED**; pending
  successors parked under `VELOCITY_LINEAGE_RETIRED_20260920`. Lesson: the Balke Tokyo-range window is a USDJPY-specific
  edge, not a transferable mechanism; the next fan-outs must pair each mechanism with its own session structure.
