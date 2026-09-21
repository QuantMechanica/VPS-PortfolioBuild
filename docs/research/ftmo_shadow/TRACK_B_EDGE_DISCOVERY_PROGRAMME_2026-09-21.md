# Track B — FTMO Shadow-Book edge-discovery programme B1 (pre-registration, Fable 2026-09-21 20:0xZ)

Authority: OWNER-DEC-FTMO-DUAL-TRACK-20260921 (`decisions/2026-09-21_owner_ftmo_dual_track_shadow_book_acceleration.md`) on
OWNER-DEC-FTMO-FINAL-MEGA-20260921 / OWNER-DEC-FTMO-BOOK-PORTFOLIO-20260921. This document is committed BEFORE any cell of the
prescreen runs; the prescreen tool reads its grid from here. Programme id `B1_NY_CASH_SESSION`.

## 1. The missing portfolio role (from `docs/ftmo/FTMO_BOOK_CURRENT.md` §5)

Dense, session-flat, low-overlap positive drift during the New-York / index-cash hours. The incumbent six have zero exposure to
that window (13213 trades Tokyo/London USDJPY; the other five are multi-day swing). Book failure mode = SLOW (median 289 bd to +10 %,
489 bd to first payout at 27.5 USD/bd financed); survival is not the binding constraint. A sleeve for this role must: earn in
13:30–20:00Z (NY cash hours) or the 30 minutes around the 09:30 ET open, be flat by 16:00 ET (0 % overnight, no swap), trade on at
least 40 % of business days, keep the day's max adverse excursion bounded (single stop per trade, ≤ 1 R), and show low downside
co-movement with the XAU cluster and the USDJPY breakout.

## 2. Funnel state (this programme)

| Stage | Count 2026-09-21 20:0xZ |
|---|---|
| HYPOTHESES_GENERATED | 8 (H-B1..H-B8 below) + Antigravity alternative set pending (`2caa90f8`) |
| CHEAP_PRESCREEN_SURVIVORS | 0 (prescreen not yet run) |
| INDEPENDENTLY_CRITIQUED / MECHANIZED / COMPILED / Q02 / Q04 / Q08 / MARGINAL_POSITIVE / SHADOW_BOOK | 0 |

Machine mirror: `D:/QM/reports/state/ftmo_edge_funnel.json` (written by the prescreen tool and by Fable at every stage change).

## 3. Execution model of the prescreen (the H-V4 lesson, OWNER §9)

Harness v1 filled stop orders at the exact level on the M1 bar that touched it (bid-only, zero spread). That produced the H-V4
false positive (release-tick stops). The Track-B prescreen (`velocity_family_f2_cash_session_0921.py`, deterministic Python over the
M1 `.hcc` history, 0 factory hours) uses a **conservative, closed-bar execution model**:

- Signals are evaluated only on **completed** bars of the signal grid (M5 / M15 / M30 bars built from M1, NY-anchored).
- Entries are **market orders at the open of the bar after the signal bar**, filled at `open + half_spread + slippage` for buys
  (`open − half_spread − slippage` for sells). Spread and slippage are per-symbol constants from the FTMO venue where measured
  (XAUUSD median 44 points; GER40 measured) and conservative priors elsewhere (indices 1.0 index point RT, FX 1.0 pip RT),
  recorded per cell in the output so the venue-fidelity work (`73434cab`) can replace them.
- Stops are **filled at the worse of the stop level and the open of the first M1 bar whose low/high breaches it** (gap-through is
  charged in full); a bar touching both stop and target scores the stop. Targets are limit fills at the level only if the bar
  trades through it by at least one tick.
- **No stop-entry orders, no release-tick placements**: a cell whose entry would coincide with a scheduled high-impact release
  (framework news blackout PRE30/POST30, strict symbol currencies) is skipped, exactly as the EA would.
- Time exit: flat at the first M1 bar at/after the flat time, at that bar's open minus half spread.
- Costs: commission from `framework/registry/live_commission.json` (round trip), no financing (session-flat by construction).
- RISK_FIXED 1000 per trade; R = net / 1000. Lot sizing via the same `lot_and_notional` helper as family F1.

The model is deliberately harsher than a real-tick tester on entries and stops. A cell that clears the bars below under this model
is `WORTH_MT5_TEST`; the MT5 Q02 canary remains the economic judge (OWNER §K).

## 4. Pre-registered hypotheses (all: one trade per day per symbol unless stated; SEL 2018-07-02..2022-12-31, VAL 2023-01-01..2025-12-31)

| Id | Mechanism (economically distinct) | Symbols | Signal grid | Mechanics (frozen) | Fragility prior |
|---|---|---|---|---|---|
| **H-B1 cash-open mean reversion** | overnight-imbalance unwind after the 09:30 ET index open | NDX, SP500, WS30, GDAXI (15:30 CET open for GDAXI) | M5 | at 09:30 ET compute the gap = open of the first cash M5 bar vs prior cash close; if |gap| ≥ 0.35 × ATR(14, D1 cash-session ranges) and the first three M5 bars do not extend the gap (third bar closes back inside the first bar's range) → fade toward the prior close at the open of bar 4; stop = the extreme of bars 1–3 (min 0.4 ATR), target = prior cash close, time exit 11:30 ET | ROBUST (market entry on a closed-bar condition) |
| **H-B2 post-open continuation** | the first 30 min sets the day's direction when volume is one-sided | NDX, SP500, GDAXI | M15 | the two 15-min bars after the open both close in the same direction with bodies ≥ 60 % of range and the second closes beyond the first's extreme → enter at the open of bar 3 in that direction; stop = the low/high of bar 1; target = 1.5 × stop distance; flat 15:45 ET | ROBUST |
| **H-B3 opening-range failure** | false breakout of the 30-min opening range | NDX, SP500, WS30 | M5 | OR = high/low of 09:30–10:00 ET; a M5 bar closes outside the OR and the next M5 bar closes back inside → enter at that bar's close direction (toward the OR midpoint) at the next open; stop = the breakout extreme; target = OR midpoint; flat 12:00 ET | MODERATE (depends on the false-break extreme) |
| **H-B4 intraday pullback continuation** | trend-day pullback to VWAP-like mean | NDX, SP500 | M5 | trend qualifier: price at 10:30 ET is beyond the OR by ≥ 0.5 × OR width; entry on the first M5 bar that closes back beyond the 20-bar M5 SMA after touching it (pullback) in the trend direction, at the next open; stop = pullback low/high; target = 2 × stop distance; flat 15:45 ET | ROBUST |
| **H-B5 volatility-compression release** | NR7-style compression of the 10:00–11:30 ET range releases into the afternoon | NDX, SP500, GDAXI, XAUUSD | M15 | if the 10:00–11:30 ET range ≤ 0.35 × the median of the last 10 days' same-window ranges → enter at the first M15 close outside that range after 11:30 ET (closed-bar, market at next open); stop = opposite side of the compression range; target = 1.5 × range; flat 15:45 ET | MODERATE (breakout, but closed-bar confirmed, no stop orders) |
| **H-B6 time-of-day reversal** | the 10:00–10:30 ET reversal window (European close flows / first-hour exhaustion) | NDX, SP500, WS30 | M5 | if the move from 09:30 to 10:00 ET ≥ 0.6 × ATR(14, D1 cash) in one direction and the 10:00–10:15 bars fail to make a new extreme → fade at the open of the 10:15 bar; stop = the 09:30–10:15 extreme; target = 50 % retracement of the 09:30–10:00 move; flat 12:30 ET | ROBUST |
| **H-B7 overnight-to-cash transition (XAU)** | Gold's London-fix / NY-open transition: the 08:00–09:30 ET drift continues or reverses at the COMEX open | XAUUSD | M15 | drift = close 09:30 ET − close 08:00 ET; if |drift| ≥ 0.5 × ATR(14, H1) → trade WITH the drift at the open of the 09:45 bar if the 09:30 bar closed in the drift direction, else AGAINST; stop = 1.0 × ATR(14, H1); target = 1.0 × stop; flat 13:30 ET | ROBUST |
| **H-B8 FX NY-session effect** | London/NY overlap continuation of the London-session move in EURUSD / GBPUSD | EURUSD, GBPUSD | M15 | London move = close 12:00 ET − close 03:00 ET (London open); if |move| ≥ 0.6 × ATR(14, D1) and the 12:00–13:00 ET bars retrace ≤ 38 % → enter with the London direction at the open of the 13:15 bar; stop = the 12:00–13:00 extreme against; target = 1.0 × stop; flat 16:30 ET | ROBUST |

Parameters in the table are frozen; no per-cell tuning. Each hypothesis is one cell per symbol (H-B1..H-B8 × symbols = 25 cells).
That is the entire family; there is no grid to search, so multiple-testing control is the family-level Bonferroni bar below.

## 5. Pre-registered pass rule (SEL) and confirmation (VAL)

- **Selection bar (SEL, 1,175 bd):** trades ≥ 300; E[R] net ≥ +0.08 R (conservative model); PF ≥ 1.15; worst-year DD ≤ 20 R;
  density ≥ 0.40 trades/bd; block-bootstrap (20-day blocks, 200 resamples) P(chance meets the bar) ≤ 0.05 / 25 cells = **0.002**
  (family-level Bonferroni).
- **Confirmation (VAL, 782 bd):** E[R] net > 0, PF ≥ 1.05, VAL R/bd ≥ 50 % of SEL R/bd, no VAL year with DD > 25 R.
- **Kill:** any SEL failure kills the cell; a VAL failure kills the cell for this lineage (a revision after seeing VAL is new lineage).
- **Survivor → WORTH_MT5_TEST** (never ECONOMICALLY_VALIDATED); next steps: Antigravity critique, mechanisation card
  (`QM-RESEARCH://` artifact), Codex build, Q02 canary, Q04, financed marginal with resolution (≥ +0.01 LCB, cost-stress robust),
  SHADOW_BOOK.
- **Control cells:** H-B1 on NDX is also run with the fill model switched to the harness-v1 model to quantify the fill-model
  gap on this family (report only).

## 6. Data and provenance

M1 `.hcc` custom history 2018–2025 (T2..T10 `Bases/Custom/history`, reader `hcc_m1_reader_0921.py`, validated 194,574/194,575
bars against the terminal export). Server clock = NY-close (UTC+2/+3), converted with the family-F1 helpers; anchors are defined in
America/New_York and mapped through the DST table. Index cash sessions: NDX/SP500/WS30 09:30–16:00 ET; GDAXI 09:00–17:30 CET
(the GDAXI cells use the CET open, mapped to ET for the flat time). Holidays/half days are taken from the data (no bars = no trade).

## 7. Cadence and ownership

- Fable: this pre-registration, the F2 prescreen tool (deterministic Python), survivor selection, integration.
- Antigravity (`2caa90f8`): independent alternative hypothesis set + fragility/overlap assessment; later the survivor critiques.
- Codex: harness v2 hardening (`7088da77`) in parallel; builds of survivors (`build_ea` from the mechanisation cards).
- MT5: Q02 canaries of survivors (factory is idle — the candidate-supply bottleneck the OWNER named).
- Reporting: OWNER §21 fields at every material report; funnel counts in `ftmo_edge_funnel.json`.

## 8. Result of family B1 (run 2026-09-21 20:10–20:2xZ, `velocity_family_f2_cash_session_0921.json`, 0 factory hours)

**0 of 22 cells pass the SEL bar; 0 survivors** (expected false survivors under the family null: 0.10). 15 cells `CLEAR_REJECT`,
7 `UNKNOWN` (too few signals to judge). Three planned cells did not evaluate (no UK100 hypothesis; two GDAXI cells had no sampled
window). Per-cell table in the JSON. One tool amendment after the first pass: a pre-registered **minimum stop of 5 x the round-trip
spread** (`stop_too_tight` state) — the first pass had a one-tick stop on GBPUSD H-B8 that produced a nonsense lot size; the amended
run is the recorded one.

| Hypothesis | Cells | Best cell (SEL E[R], PF, n) | Reading |
|---|---|---|---|
| H-B1 cash-open MR | 4 | GDAXI −0.11 R / 0.71 / 196 | consistently negative on all four indices — fading the open gap after a 3-bar stall loses |
| H-B2 post-open continuation | 3 | GDAXI **+0.10 R / 1.24 / 44**; NDX +0.04 / 1.12 / 67 (VAL +0.08 / 1.22 / 55) | the only positive mechanism, but the body filter leaves 0.04–0.06 trades/bd — density fails; a relaxed qualifier is new lineage (B2) |
| H-B3 OR failure | 3 | NDX −0.27 / 0.53 / 669 | cost-destroyed: stops of a few index points vs 0.4–2 pt spread+slip; SP500/WS30 PF < 0.1 |
| H-B4 pullback continuation | 2 | NDX −0.34 / 0.54 / 90 | negative and thin |
| H-B5 compression release | 4 | all UNKNOWN (6–19 trades) | the 0.35 x median threshold almost never fires; calibrate density before mechanics (B2) |
| H-B6 time-of-day reversal | 3 | all UNKNOWN (7–15 trades) | the 0.6 ATR first-half-hour move is rare; Antigravity also notes the European close is 11:30 ET, not 10:00 |
| H-B7 XAU transition | 1 | **−0.18 R / 0.68 / 613 (VAL −0.17 / 0.70 / 468)** | a strongly and consistently wrong-signed rule at 0.5 trades/bd — the COMEX-open drift REVERSES; a reversed rule is a post-hoc hypothesis and enters B2 as new lineage with a stricter bar |
| H-B8 FX NY session | 2 | GBPUSD −0.13 / 0.67 / 342 | negative; Antigravity: the flow is the 11:00 ET WMR fix, not 13:15 |

Lessons carried into B2: (1) index intraday mechanics need ATR-based stops (≥ 0.3 x cash-session ATR) or they are cost-dominated at
FTMO spreads; (2) pre-register density targets and calibrate thresholds on the SEL density only (never on P/L) before a mechanism is
judged; (3) the conservative fill model is fit for purpose — nothing survived it that a real-tick tester would later kill.

## 9. Family B2 — pre-registration (to run next; frozen here before any cell runs)

Sources: Antigravity `2caa90f8` (`agy_edge_generation_2caa90f8.md`, specs verbatim per its §3) and the B1 lessons. Same execution
model, SEL/VAL split, pass rule and family-level Bonferroni bar (0.05 / number of B2 cells). Cells:

| Id | Mechanism | Symbols | Spec source |
|---|---|---|---|
| H-AG2 | post-initial-balance momentum (IB 09:30–10:00 break by ≥ 0.10 D1-ATR with body ≥ 60 %, stop IB midpoint, target 1.5 R, flat 15:45) | SP500, NDX | agy §3 H-AG2 |
| H-AG1 | cash-open OR fade (gap ≥ 0.40 D1-ATR; bar-3 reversal; stop = 09:30–09:45 extreme + 0.2 H1-ATR; target 50 % retracement; flat 11:30) | NDX, SP500 | agy §3 H-AG1 |
| H-AG4 | overnight-range failure rejection (globex 18:00–09:15 range; 09:30 bar breaches ≥ 15 pt, 09:45 bar closes back inside; stop = trap extreme + 20 pt; target overnight midpoint; flat 12:30) | WS30, NDX | agy §3 H-AG4 |
| H-AG5 | COMEX pit-open liquidity sweep MR (03:00–08:15 range; 08:20–08:55 sweep ≥ 1 USD with ≥ 50 % wick close-back; release days skipped; stop sweep extreme + 1.5 USD; target London midpoint / 2 R; flat 11:00) | XAUUSD | agy §3 H-AG5 |
| H-AG6 | equity-to-FX yield transmission (09:30–15:30 USDJPY following the first-hour equity direction) | USDJPY | agy §3 H-AG6 |
| H-AG8 | WMR 16:00 London fix pre-hedge (10:15–11:05 ET) | GBPUSD, EURUSD | agy §3 H-AG8 |
| H-B2r | post-open continuation, relaxed: bodies ≥ 40 %, second bar close beyond the first bar extreme, stop = max(bar-1 extreme, 0.3 x cash ATR), target 1.5 R, flat 15:45 | NDX, SP500, GDAXI | this doc (derived from B1 H-B2 — new lineage) |
| H-B7r | XAU COMEX-open drift REVERSAL: same signal as H-B7, opposite direction, stop = 1.0 H1-ATR, target 1.0 R, flat 13:30; **post-hoc lineage** — bar raised to E[R] ≥ +0.12 R, PF ≥ 1.25 and chance ≤ 0.001 | XAUUSD | this doc (derived from B1 H-B7 — post-hoc, stricter bar) |

15 cells; family bar 0.05 / 15 = 0.0033 (H-B7r 0.001). Antigravity H-AG3 (GDAXI European close), H-AG7 (post-lunch compression),
H-AG9 (NYMEX open), H-AG10 (EURUSD VWAP pullback) are parked for B3 pending the B2 density readings.

## 10. Family B3 — Codex intake break-and-retest hypotheses (pre-registration by reference; frozen before the run)

Source: `docs/research/ftmo_intake/2026-09-21_br_nnfx/PLAN.md` (Codex, OWNER request OWNER-REQUEST-FTMO-BR-NNFX-20260921, cherry-picked
ed3eef5a0d) — section "Three new Break & Retest hypotheses", rules implemented verbatim in
`tools/strategy_farm/session_tools/velocity_family_f3_break_retest_0921.py` on the F2 conservative closed-bar engine. Two documented
deviations: ATR(14) is the simple 14-bar mean of the M5 true range (MT5 iATR semantics, family-F1 convention) instead of Wilder
smoothing; bid/ask is the per-symbol cost prior (spread + slippage round trip). The F2 minimum-stop floor (5 x round-trip spread) stays in
force as the "executable under broker stop-distance constraints" rule of the PLAN.

| Id | Markets / anchor | Arms (paired) | Entry / flat |
|---|---|---|---|
| BR1 | NDX, SP500, WS30; 09:30–09:45 NY opening range | `retest_peer` (peer index closed outside its own OR in the same direction at retest close: SP500 for NDX/WS30, NDX for SP500) vs `retest_nopeer` | entries 09:45–11:30 NY; flat 15:45 NY |
| BR2 | EURUSD, GBPUSD, USDJPY; 00:00–07:00 London range | `retest_compressed` (range ≤ median of the preceding 20 same-window ranges) vs `retest_any` | entries 08:00–10:30 London; flat 12:00 London |
| BR3 | XAUUSD, XAGUSD; 08:00–12:00 London range | `retest` (full retest package) vs `direct_breakout` (next open after the breakout, 1 ATR stop, 1.5 R target) | entries 08:00–11:00 NY after the London range closed; flat 13:00 NY |

Common engine: breakout = M5 close > level + 0.10 ATR with the previous close at/below; retest within 6 later bars (low ≤ level + 0.10 ATR,
low ≥ level − 0.25 ATR, close > level, close > open); invalidation on a close > 0.25 ATR through the wrong side, window expiry, or an entry
open > 0.50 ATR past the retest close; stop = retest extreme ∓ 0.10 ATR, min 0.50 ATR, skip > 1.50 ATR or if the open already crossed it;
target 1.5 R; exit at the next open after the first completed close back through the level; one entry per symbol/day; no re-arm.
16 cells, family bar 0.05 / 16 = 0.0031; same SEL/VAL rule as B1/B2.

### B3 result (2026-09-21T20:23:25Z, `docs/research/ftmo_intake/2026-09-21_br_nnfx/results/`)

**0 of 16 cells pass; 0 survivors.** The retest package rarely completes (invalidated/expired on 70-85 % of armed days, density <= 0.18/bd) and
where it fires the M5-ATR stops are cost-dominated (index cells -0.6 to -2.2 R per trade, median hold 7-11 min; controls fail identically).
Same class as B1 H-B3/H-B4. BR1-BR3 = CLEAR_REJECT for the velocity role; a D1-ATR-scale / hourly-window re-specification would be a new
lineage (B4 candidate) only after a density calibration.

### B2 result (2026-09-21T20:45:29Z, `velocity_family_f4_b2_0921.json`, tool `velocity_family_f4_b2_0921.py`)

**0 of 14 evaluated cells pass the selection bar; 0 survivors** (expected false survivors 0.005; one cell, H-AG6 USDJPY, produced no
qualifying day after the fix of the day-range ATR helper — its double confirmation with SP500 at 0.20 D1-ATR each never co-occurred with a
closed-data 09:30-10:00 window on the .DWX history and it is UNKNOWN). Every index cell is CLEAR_REJECT; the two relaxed post-open
continuation cells (H-B2r GDAXI / NDX) are marginally positive in SEL (+0.02 R, PF 1.05) with 0.10-0.16 trades/bd — density and edge both
short of the bar; the XAU drift reversal H-B7r is negative after costs (−0.07 R at 0.52/bd) although its sign is the mirror of B1 H-B7 —
the mechanism is a cost sink in both directions; H-AG5 (COMEX sweep) fires rarely and loses; H-AG8 (WMR fix) and H-AG6 fire too rarely.

| Cell | State | SEL n | E[R] | PF | worst-year DD R | trades/bd | median hold min | VAL n | E[R] | PF | chance |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| H-B2r|GDAXI.DWX | CLEAR_REJECT | 117 | 0.0227 | 1.048 | 9.49 | 0.0996 | 300.0 | 94 | 0.0348 | 1.074 | None |
| H-B2r|NDX.DWX | CLEAR_REJECT | 187 | 0.0219 | 1.055 | 12.05 | 0.1591 | 246.0 | 127 | -0.027 | 0.938 | None |
| H-B7r|XAUUSD.DWX | CLEAR_REJECT | 613 | -0.0686 | 0.862 | 28.79 | 0.5217 | 24.0 | 468 | -0.0341 | 0.93 | 0.005 |
| H-AG2|NDX.DWX | CLEAR_REJECT | 211 | -0.0865 | 0.827 | 13.0 | 0.1796 | 210.0 | 166 | 0.0487 | 1.11 | None |
| H-AG8|GBPUSD.DWX | UNKNOWN | 40 | -0.1141 | 0.66 | 4.06 | 0.034 | 35.0 | 36 | -0.0626 | 0.817 | None |
| H-AG4|NDX.DWX | CLEAR_REJECT | 114 | -0.1145 | 0.559 | 5.62 | 0.097 | 26.0 | 70 | -0.0996 | 0.641 | None |
| H-AG6|USDJPY.DWX | CLEAR_REJECT | 58 | -0.1238 | 0.738 | 5.14 | 0.0494 | 168.5 | 26 | 0.2329 | 1.79 | None |
| H-B2r|SP500.DWX | CLEAR_REJECT | 185 | -0.2669 | 0.543 | 17.62 | 0.1574 | 240.0 | 111 | -0.124 | 0.767 | None |
| H-AG5|XAUUSD.DWX | CLEAR_REJECT | 58 | -0.2757 | 0.51 | 7.75 | 0.0494 | 21.0 | 68 | -0.1437 | 0.748 | None |
| H-AG8|EURUSD.DWX | CLEAR_REJECT | 53 | -0.3046 | 0.339 | 7.0 | 0.0451 | 35.0 | 38 | -0.041 | 0.861 | None |
| H-AG1|NDX.DWX | CLEAR_REJECT | 164 | -0.3697 | 0.259 | 24.81 | 0.1396 | 5.0 | 109 | -0.2414 | 0.444 | None |
| H-AG2|SP500.DWX | CLEAR_REJECT | 212 | -0.4451 | 0.391 | 25.19 | 0.1804 | 153.0 | 156 | -0.1955 | 0.677 | None |
| H-AG4|WS30.DWX | CLEAR_REJECT | 174 | -0.5538 | 0.173 | 35.82 | 0.1481 | 29.0 | 161 | -0.5307 | 0.145 | None |
| H-AG1|SP500.DWX | CLEAR_REJECT | 180 | -1.2026 | 0.01 | 69.46 | 0.1532 | 4.0 | 103 | -0.9861 | 0.028 | None |

Reading. Across four families (H-V1..V4, B1, B2, B3: 67 cells, six hand-written mechanism classes) nothing in the NY/index-cash-session
role survives the conservative fill model on the .DWX history. The consistent pattern: (1) intraday index mechanics with M5/M15-scale
stops are cost-dominated at FTMO spread priors; (2) the M15 continuation class shows the only positive SEL drift, but at 0.1-0.2 trades/bd;
(3) fixed-time reversal/fade rules are wrong-signed or neutral. Consequence (OWNER full-throttle §12-15): the next families come from the
systematic scanners (Codex cross-symbol scanner `35bbe0bc`, ML rule discovery `08d62fa7`, Kimi wave `9d7458f8`, Antigravity cross-symbol
set `7636afc9`) rather than from further hand-written single-symbol session rules; Track C runs the N2 NNFX H1 family (`C1`) in parallel.

### C1 (N2) result (2026-09-21T20:46:34Z) — Track C, NNFX H1 lean stack

0 of 8 cells pass (session-flat and all-hours, EURUSD/GBPUSD/USDJPY/XAUUSD): E[R] −0.07 to −0.14 R after costs at 0.27-0.61 trades/bd —
a genuine economic rejection, not signal starvation. Details in `docs/research/ftmo_intake/2026-09-21_br_nnfx/results/README.md`.
Running total 2026-09-21: 5 families, 89 cells, 0 survivors under the conservative fill model.

## 11. B4 pre-registration (2026-09-21T20:57:43Z) — cross-symbol / multi-condition family (Antigravity 7636afc9, APPROVED)

Source: `docs/research/ftmo_shadow/agy_cross_symbol_hypotheses_7636afc9.md` (12 hypotheses; 5 killed on paper by their own attack:
H-CS11 WMR basket cost trap, H-CS08 metals-ratio runaway, H-CS04 Globex data artefact, H-CS03 sector conflict, H-CS06 BoJ headline risk).
The 7 paper survivors run as family B4 in the F2 engine, tool `tools/strategy_farm/session_tools/velocity_family_f6_cross_symbol_0921.py`,
each with one control arm — 14 cells, family Bonferroni bar 0.05/14 = 0.00357, SEL/VAL rule and fill model unchanged from section 3/5:

| Cell | Execution | Reference | Rule (closed data → market at next open) | Stop | Target / flat | Control arm |
|---|---|---|---|---|---|---|
| H-CS01 | SP500 | GDAXI | DAX 07:00-09:15 ET move ≥0.30 D1-ATR on the trending side of its 20-bar M15 SMA; SP500 09:30-09:45 bar same direction, body ≥40 % | max(bar extreme, 0.40 D1-ATR, 8 pt) | 1.75 R / 15:45 ET | noref: SP500 bar alone |
| H-CS02 | NDX | SP500 | SP500 10:00-10:15 close beyond its 09:30-10:00 IB by 0.05 D1-ATR; NDX same bar closes beyond its IB, body ≥50 % | max(IB midpoint, 0.35 D1-ATR) | 1.75 R / 15:45 ET (no BE trail) | noref: NDX IB break alone |
| H-CS05 | XAUUSD | XAGUSD | silver 08:15-08:30 close beyond its 03:00-08:00 range by 0.20 H1-ATR; gold same bar beyond its range | max(0.75 H1-ATR, 6 USD) | 1.5 R / 13:30 ET | noref: gold break alone |
| H-CS07 | XAUUSD | (self) | London 03:00-10:00 drift ≥0.60 D1-ATR; 10:00-10:15 bar in drift direction | max(0.60 H1-ATR, 09:45-10:15 range, 8 USD) | 1.5 R / 13:30 ET | fade: against the drift (must lose) |
| H-CS09 | USDJPY | SP500 | SP500 09:30-10:00 impulse ≥0.25 D1-ATR with 09:45-10:00 body ≥50 %; USDJPY 09:45-10:00 bar same direction | max(0.60 H1-ATR, 22 pips) | 1.5 R / 15:45 ET | noref: USDJPY bar alone |
| H-CS10 | EURUSD | GBPUSD | both 03:00-08:15 moves ≥0.35 D1-ATR and aligned; EURUSD retrace ≤38.2 % into 08:30 (09:00 on release days) | max(0.65 H1-ATR, 20 pips) | 1.5 R / 16:00 ET | noref: EURUSD move alone |
| H-CS12 | USDCAD | XTIUSD | WTI 09:00-10:00 move ≥0.50 H1-ATR → USDCAD opposite | max(0.65 H1-ATR, 20 pips) | 1.5 R / 16:00 ET | self: USDCAD own 09:00-10:00 impulse |

Pass rule per cell unchanged (SEL n≥300, E[R]≥0.08, PF≥1.15, DD≤20 R, density≥0.40/bd, chance≤bar; VAL confirmation). The reference
condition earns its keep only if the `ref` arm beats its control on SEL E[R] by ≥ +0.10 R (source falsification test); a `ref` cell that
passes while its control also passes is a single-symbol finding, not a cross-symbol one. Recorded resolutions: entries at the open of the
first bar after the last closed bar the rule reads; D1 ATR = mean of the previous 14 full server-day ranges; H1 ATR = simple 14-bar mean;
engine stop floor 5 × round-trip spread on top of each rule floor; H-CS02 breakeven trail not modelled. Cost priors: USDCAD 1.5 pip RT,
XTIUSD/XAGUSD reference-only priors. 0 factory hours; discovery 2018-07..2022, validation 2023..2025.

