---
ea_id: QM5_11570
slug: wilder-tbp-momentum-d1
source_id: 0ab0a479-4a09-5ecc-bb90-6a37148fa78b
source_title: "New Concepts in Technical Trading Systems"
source_author: J. Welles Wilder Jr.
r1: PASS
r2: PASS
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_trades_per_year_per_symbol: 120
phase: G0
status: draft
period: D1
target_symbols:
  - EURUSD.DWX
  - GBPUSD.DWX
  - USDJPY.DWX
  - AUDUSD.DWX
  - USDCAD.DWX
  - USDCHF.DWX
  - GBPJPY.DWX
created_at: 2026-05-23
g0_status: APPROVED
g0_approval_reasoning: "R1 single source_id/book attribution; R2 mechanical D1 momentum local-high/low entries with TP/SL exits and frequent daily signal cadence above 2 trades/year/symbol; R3 OHLC-only logic testable on DWX FX CFDs; R4 deterministic non-ML one-position no martingale."
last_updated: 2026-05-23
---

## Concept

Source citation: J. Welles Wilder Jr., *New Concepts in Technical Trading Systems*, 1978. URL: local book/source registry entry `0ab0a479-4a09-5ecc-bb90-6a37148fa78b`.

Wilder's Trend Balance Point System (Section V, 1978). Enter when the 2-day momentum factor
makes a new local high (long) or low (short). Exit at a dynamic target or protective stop
computed from the prior bar's H/L/C. System was designed for ~70-80% win rate with small
targets and wider stops.

Original tested on US commodity futures. Adapted to Forex D1 — P2 determines viability.

Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX, GBPJPY.DWX.
Expected trades per year per symbol: 120. D1 local extrema in 2-day momentum can occur multiple times per month; the original source claim of 3-5 trades/week supports a cadence well above the G0 minimum after FX porting.

## Entry Logic

```mql5
// Momentum Factor: close minus close 2 bars ago
// MF[0] = today's MF (forming bar), MF[1] = yesterday's, MF[2] = 2 days ago

double MF0 = iClose(NULL, PERIOD_D1, 1) - iClose(NULL, PERIOD_D1, 3);  // yesterday's MF
double MF1 = iClose(NULL, PERIOD_D1, 2) - iClose(NULL, PERIOD_D1, 4);  // 2 days ago
double MF2 = iClose(NULL, PERIOD_D1, 3) - iClose(NULL, PERIOD_D1, 5);  // 3 days ago

// Entry on close (i.e., check after bar close, execute at next open)
bool LONG  = (MF0 > MF1) && (MF0 > MF2);  // today's MF higher than both previous
bool SHORT = (MF0 < MF1) && (MF0 < MF2);  // today's MF lower than both previous
```

## Exit Logic

Computed from the entry bar (previous day) after close:

```mql5
double H = iHigh(NULL, PERIOD_D1, 1);
double L = iLow(NULL, PERIOD_D1, 1);
double C = iClose(NULL, PERIOD_D1, 1);
double X = (H + L + C) / 3.0;  // typical price

double TR = MathMax(H - L,
            MathMax(MathAbs(H - iClose(NULL, PERIOD_D1, 2)),
                    MathAbs(L - iClose(NULL, PERIOD_D1, 2))));

// Protective stops
double stop_long  = X - TR;   // stop for long trade
double stop_short = X + TR;   // stop for short trade

// Profit targets
double target_long  = 2.0 * X - L;  // 2X - Low
double target_short = 2.0 * X - H;  // 2X - High
```

Exit when TP or SL hit. On reaching target (not stop), do NOT reverse — wait for next signal.
On stop hit, do NOT reverse — wait for next signal.

## Risk / SL

SL = X - TR (Long) or X + TR (Short). Computed from prior bar's OHLC each session.
No pip cap — the stop is derived from the actual bar's volatility.

P2 note: `RISK_FIXED = 1000 USD`. Widen the default stop by 20% for Forex spreads if needed.

## P2 Parameter Sweep

No free parameters — the system is self-calibrating via true range.

P3 variant: test exiting on a fixed bar count (e.g., 3-5 bars) when target is not reached.

## Notes

- Original: "~70-80% profitable trades, averages 3-5 trades/week" (commodity futures).
- Short TP and wider stop means positive win rate but may have negative expectancy on Forex —
  P2 will determine. The system was designed for commodity futures momentum, not Forex.
- R1 PASS: Wilder is the inventor of RSI, ATR, Parabolic SAR, ADX.
- R2 PASS: pure OHLC arithmetic (H, L, C from previous bar only).
- Wilder also specifies a Trend Balance Point (TBP) as an alternate stop/reverse level;
  this implementation uses the simpler X±TR stop as the primary risk control.
