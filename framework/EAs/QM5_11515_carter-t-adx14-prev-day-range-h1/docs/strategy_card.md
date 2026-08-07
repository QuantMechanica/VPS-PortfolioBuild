---
ea_id: QM5_11515
slug: carter-t-adx14-prev-day-range-h1
type: strategy
source_id: 8794b680-f6f4-5142-b12c-e5e0057e7bcf
sources:
  - "[[sources/carter-thomas-20-forex-trend-following-systems]]"
concepts:
  - "[[concepts/prior-day-range]]"
  - "[[concepts/adx-range-filter]]"
  - "[[concepts/mean-reversion-breakout]]"
indicators:
  - ADX(14)
period: H1
source_citation: "Thomas Carter, 'Forex Trend Following Strategies: 20 Trend Following Systems', self-published 2014 (System #11). R1 CONDITIONAL — named individual, self-published ebook."
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: Single source_id present; Thomas Carter self-published ebook is a valid source per R1 (author track record not required).
r2_mechanical: PASS
r2_reasoning: ADX(14) range filter, prior-day H/L lookup, BuyStop/SellStop with session expiry — all deterministic MT5-native iADX/iHigh/iLow calls.
r3_data_available: PASS
r3_reasoning: Targets EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX — live-tradable DWX FX instruments with H1+D1 history available.
r4_ml_forbidden: PASS
r4_reasoning: Indicator threshold comparisons only; no ML, no adaptive PnL parameters, one position per magic.
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 50
g0_approval_reasoning: "R1 PASS single source_id Carter ebook; R2 PASS mechanical H1 ADX prior-day false-break pending-order rules with daily opportunity cadence plausibly >2 trades/year/symbol; R3 PASS DWX FX H1/D1; R4 PASS deterministic no ML 1-pos compatible."
---

# QM5_11515 Carter-T — ADX(14) + Prior-Day Range Fade/Breakout (H1)

## Quelle
- Source: Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following Systems", System #11, self-published 2014.
- R1: CONDITIONAL — named author, self-published ebook.

## Mechanik

**Concept**: When ADX(14) < 35 (not strongly trending = rangebound conditions), the prior day's High and Low define potential mean-reversion extremes. Price breaking 15 pips below prior day Low (false breakdown) triggers a BuyStop 15 pips above prior day High. This is a mean-reversion / false-break pattern in rangebound conditions.

**Logic**: ADX < 35 means the market is not in a strong trend — range conditions. In a range, price breaking below prior day Low by 15 pips typically attracts buyers. The BuyStop at prior day High + 15 pips captures the upside breakout of the prior range after the false down-break. Intraday logic — exit same day or at max 30-pip SL.

**QM note**: This is a mean-reversion/fade strategy in low-ADX conditions. Counter-intuitive but mechanically clean.

### Entry

**LONG (false breakdown into BuyStop):**
1. **ADX rangebound**: `iADX(NULL,PERIOD_H1,14,PRICE_CLOSE,MODE_MAIN,1) < 35`
2. **Prior day levels**: `prev_day_high = iHigh(NULL,PERIOD_D1,1)`, `prev_day_low = iLow(NULL,PERIOD_D1,1)`
3. **Price 15 pips below prior day Low**: `iLow(NULL,PERIOD_H1,0) < prev_day_low - 15*pip` (current H1 bar printed below)
4. **Place BuyStop**: at `prev_day_high + 15*pip`; valid for current D1 session only
5. **SL**: 30 pips below BuyStop trigger: `entry - 30*pip`
6. **TP**: 2×risk = 60 pips, OR fixed 60 pips (source-specified)

**SHORT (false breakout into SellStop):**
1. ADX(14) < 35
2. Price prints 15 pips above prior day High
3. Place SellStop at `prev_day_low - 15*pip`
4. SL: 30 pips; TP: 60 pips

### Exit
- **TP**: 60 pips (source-specified; = 2×30 pip SL)
- **SL**: 30 pips (source-specified)
- Pending order expires end of D1 session if not triggered

### Stop Loss
- `SL_long = entry - 30*pip`
- `SL_short = entry + 30*pip`
- Source: 30 pips. P2 cap: 30 pips (use source value).

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: H1 (for reading current price action and ADX)
- Instruments: EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX
- Spread cap: 15 pips
- No Friday entry

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | CONDITIONAL | Thomas Carter, self-published ebook. No verifiable credentials. |
| R2 Mechanical | PASS | ADX(14): iADX. Prior-day H/L: iHigh(D1,1)/iLow(D1,1). BuyStop arithmetic. All MT5-native. |
| R3 Data Available | PASS | H1 + D1 DWX FX. MT5-native. |
| R4 No ML | PASS | Threshold comparisons only. No ML. |

G0 APPROVE eligible with CONDITIONAL R1 note. Prior-day range + ADX filter combination is mechanically clean. BuyStop pending order management (expiry = session end) is standard. P2 must verify false-break frequency vs direct-breakout rate.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Thomas Carter, "Forex Trend Following Strategies", System #11, 2014

## Implementation Notes for Codex (P1)
- `double adx = iADX(NULL,PERIOD_H1,14,PRICE_CLOSE,MODE_MAIN,1)`
- `double pd_high = iHigh(NULL,PERIOD_D1,1)`, `double pd_low = iLow(NULL,PERIOD_D1,1)`
- False breakdown detect: current H1 bar Low < `pd_low - 15*pip`
- BuyStop at `pd_high + 15*pip`; SL: `entry - 30*pip`; TP: `entry + 60*pip`
- Order expiry: midnight broker time (end of D1 session)
- Only one pending order per direction per session
- P3 sweeps: ADX threshold (25/30/35), false-break offset (10/15/20 pips), BuyStop offset (10/15/20 pips above PD high), SL/TP (20/30/40 pips / 40/60/80 pips)

## Verwandte Strategien
- Related: QM5_11513 (carter-t-ema4-11-adx13-d1) — same source, ADX trend filter D1
- Related: QM5_11522 (carter-t-ema4-10-adx28-macd5104-h4) — same source, ADX H4
- Related: QM5_11505 (goodwin-hourly-breakout-h1) — similar prior-day filter H1

## Lessons Learned
- *(populated as pipeline progresses)*
