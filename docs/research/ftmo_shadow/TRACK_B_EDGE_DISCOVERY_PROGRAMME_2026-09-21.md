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

