---
ea_id: QM5_11465
slug: suhr-bank-trading-stop-run-fade-h1
type: strategy
source_id: 966a64b0-7975-5f93-81f6-ddc316a4e029
sources:
  - "[[sources/tradingpub-6-simple-strategies-forex]]"
concepts:
  - "[[concepts/stop-run-fade]]"
  - "[[concepts/manipulation-level]]"
  - "[[concepts/prior-day-high-low]]"
  - "[[concepts/rejection-candle]]"
  - "[[concepts/mean-reversion]]"
indicators: []
period: H1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX]
source_citation: "Sterling Suhr, Bank Trading Stop Run Fade, in TradingPub 6 Simple Strategies for Trading Forex (~2015). DayTradingForexLive.com. R1 CONDITIONAL — named Co-Founder, self-published website source. Local PDF: 459341651-6-Simple-Strategies-for-Trading-Forex-pdf.pdf."
g0_status: APPROVED
r1_track_record: TIER_C
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-07-27
expected_trades_per_year_per_symbol: 10
card_body_incomplete: true
card_body_missing: "legacy_contract_repair"
g0_rejection_reason: "SUPERSEDED: source-only rejection recovered under OWNER R1 policy on 2026-07-23; original retained in cards_rejected."
status: draft
r1_reasoning: "Existing attribution retained; R1 is informational and non-gating under OWNER policy 2026-07-23."
r2_reasoning: "Stop-run/confirmation/pullback/entry sequence is a fully deterministic state machine on OHLC and fixed pip thresholds, with explicit SL and TP; no discretion."
r3_reasoning: "H1 DWX FX data (yesterday D1 H/L and rolling H1 swing H/L) available for all five listed target symbols."
r4_reasoning: "Fixed pip thresholds and OHLC comparisons only, no ML/adaptive components, single-position state machine compatible with 1-position-per-magic."
legacy_contract_repair: true
g0_recovery_reason: "Source-only rejection recovered; fresh semantic R2-R4 G0 review required."
g0_recovery_origin: "D:/QM/strategy_farm/artifacts/cards_rejected/QM5_11465_suhr-bank-trading-stop-run-fade-h1.md"
g0_approval_reasoning: "R1 lineage recorded; R2 deterministic prior-day/swing-level stop-run state machine with explicit confirmation, pullback, stop and target, conservatively 10 trades/year/symbol; R3 testable on listed FX .DWX symbols; R4 deterministic, ML-free, one-position compatible."
expected_pf: 1.2
expected_dd_pct: 18.0
---

# QM5_11465 Suhr — Bank Trading Stop Run Fade (H1)

## Quelle
- Source: Sterling Suhr, "Bank Trading Stop Run Fade" in TradingPub 6 Simple Strategies (~2015)
- R1: CONDITIONAL — named Co-Founder/Head Trader of DayTradingForexLive; self-published/website source.

## Mechanik

**Concept**: Institutional traders ("banks") hunt stop-loss clusters around obvious reference levels — yesterday's High/Low and recent swing H/L. When price breaks one of these levels by ≥3 pips (triggering retail stops), but the candle that caused the break is then immediately rejected (next candle closes back inside the level), it signals that the break was a manipulation maneuver rather than a genuine breakout. The trade fades the direction of the stop run: buy after a false break below a support level, sell after a false break above a resistance level.

**Sequence** (must complete within 5 candles total):
1. Identify manipulation level
2. Stop run candle (breaks level by ≥3 pips — candle shape irrelevant)
3. Confirmation candle closes back inside the level
4. Pullback candle: price retraces back toward the manipulation level
5. Entry when entry price is within 15 pips of the manipulation level (so 20-pip SL clears the stop run extreme)

### Manipulation Levels (priority order)
- Yesterday's High / yesterday's Low
- Recent swing high / swing low (look back 20 bars on H1)

### Entry

**LONG (fade below-support stop run):**
1. Identify support level `M` = yesterday's Low OR recent H1 swing low (`iLowest(PERIOD_H1, MODE_LOW, 5, 2)` as lowest low among recent bars)
2. Stop run: any H1 bar has `Low < M - 3×pip` — level breached by ≥3 pips
3. Confirmation: `Close[next_bar] > M` — a subsequent bar closes back above the level within the 5-candle window
4. Pullback: price retraces toward `M`; entry when `Ask ≤ M + 15×pip`
5. Enter BUY at market; SL = `Low_of_stop_run_bar - 1pip`; must complete within 5 candles of the stop run bar
6. TP = asymmetric — primary target: next resistance / recent swing high

**SHORT (fade above-resistance stop run):**
1. Identify resistance level `M` = yesterday's High OR recent H1 swing high
2. Stop run: `High > M + 3×pip`
3. Confirmation: `Close[next_bar] < M` — closes back below level
4. Pullback: price retraces back toward `M`; entry when `Bid ≥ M - 15×pip`
5. Enter SELL at market; SL = `High_of_stop_run_bar + 1pip`
6. TP = next support / recent swing low

### Exit
- **TP**: next major level (swing opposite extreme, prior day opposite H/L) — typically 30–60 pips
- **SL**: beyond the stop-run bar extreme + 1 pip
- **Time limit**: cancel / close if not triggered within 5 H1 bars of stop run candle

### Stop Loss
- Beyond the stop-run bar extreme (High for short, Low for long) + 1 pip
- P2 cap: 60 pips (if stop run extreme is >60 pips from entry, skip the setup)

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: H1 (entry and sequence tracking)
- Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX
- Spread cap: 20 pips
- Max 5-candle sequence from stop run to entry
- Do not trade if spread ≥ SL distance

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | CONDITIONAL | Sterling Suhr, named Co-Founder of DayTradingForexLive; self-published website source, no independent verification. |
| R2 Mechanical | PASS | Manipulation level = yesterday H/L (OHLC) or rolling iLowest/iHighest. Stop run = Low < level - 3pips (arithmetic). Confirmation = Close > level (OHLC). Pullback = Ask ≤ level + 15pips (arithmetic). All MT5-native. |
| R3 Data Available | PASS | H1 DWX FX. iHigh/iLow/iClose, iLowest/iHighest bar indices MT5-native. |
| R4 No ML | PASS | Fixed pip thresholds (3 pips, 15 pips). No optimization function. |

G0 APPROVE eligible with CONDITIONAL R1 note.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Suhr, TradingPub 6 Simple Strategies (Strategy 3)

## Implementation Notes for Codex (P1)
- Yesterday H/L: `iHigh(PERIOD_D1,1)` and `iLow(PERIOD_D1,1)` — shift=1 is prior completed D1 bar
- Swing H/L (H1): `iHighest(NULL,PERIOD_H1,MODE_HIGH,20,2)` and `iLowest(NULL,PERIOD_H1,MODE_LOW,20,2)` — scan 20 bars back starting at bar 2 (skip current incomplete bar)
- Stop run detection: on each new H1 bar close, check if any bar in the lookback window broke the level by ≥3 pips
- State machine: IDLE → STOP_RUN_SEEN (bar that broke level) → CONFIRMED (next bar closed back inside) → AWAITING_ENTRY (price must reach within 15 pips) → ACTIVE; reset after 5 bars or timeout
- SL = `iLow(stop_run_bar_shift)` - 1 pip (for long); dynamic SL based on actual stop-run bar
- TP: detect next swing opposite extreme — use `iHighest(PERIOD_H1, MODE_HIGH, 10, 1)` for long TP target
- P3 sweeps: level type (yesterday-only/swing-only/both), stop run threshold (2/3/5 pips), pullback entry window (10/15/20 pips), max sequence bars (3/5/7), SL buffer (0/1/2 pips)

## Verwandte Strategien
- Related: QM5_11452 (big-ben-fade-asian-range-m5) — also a fade of a false break; Asian range vs. manipulation level; M5 vs. H1
- Related: QM5_11446 (burke-3day-rectangle-breakout-m5) — false break of a D1 consolidation range; similar rejection logic on different timeframe

## Lessons Learned
- *(populated as pipeline progresses)*
