---
ea_id: 11585
slug: neely-weller-channel-buffer-band-d1
source_id: 577eb0aa-7880-5c0a-a8f9-56cd126c19f9
source_title: "Lessons from the Evolution of Foreign Exchange Trading Strategies"
source_author: Christopher J. Neely & Paul A. Weller
source_year: 2013
r1: PASS
r2: PASS
phase: G0
status: draft
period: D1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX]
expected_trade_frequency: "D1 5-40 day channel-buffer breakout flip rule; always-in-market state changes expected 6-20 trades/year/symbol depending on lookback and band."
expected_trades_per_year_per_symbol: 10
created_at: 2026-05-23
r1_track_record: PASS
r1_reasoning: "Single source_id present linking to Neely & Weller (2013) Fed/university peer-reviewed paper; same source as QM5_11578, each card carries one source_id."
r2_mechanical: PASS
r2_reasoning: "Channel max/min with percentage buffer band; always-in-market flip on opposite breakout; pure close arithmetic with no discretion."
r3_data_available: PASS
r3_reasoning: "EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX all available as DWX D1 symbols."
r4_ml_forbidden: PASS
r4_reasoning: "Deterministic price-arithmetic always-in-market rule with fixed ATR safety SL; no ML, adaptive PnL-based parameters, grid, or martingale."
card_body_incomplete: true
card_body_missing: "target_symbols"
g0_status: APPROVED
g0_approval_reasoning: "R1 PASS single source_id Neely-Weller paper; R2 PASS mechanical D1 channel-buffer long/short flip rule with plausible 2+ trades/year/symbol from 5-40 day breakouts; R3 PASS FX DWX majors; R4 PASS deterministic no ML 1-pos."
last_updated: 2026-05-23
---

# QM5_11585 — Neely-Weller Channel Rule with Buffer Band D1

## Edge thesis

A channel breakout with a small band of inaction (x = 0.1%) prevents entries right at the channel boundary and reduces whipsaw. Only a confirmed break *beyond* the channel extreme by x% triggers a signal change. This was one of the best-performing rule families in Neely & Weller's (2013) 1973-2012 multi-currency study, though the paper notes that edge declined post-2000 for major pairs when applied naively (without adaptive rule selection).

## Target symbols

EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX on D1.

## R1 / R2

- **R1 PASS**: Federal Reserve Bank (Neely) + University of Iowa (Weller); SSRN working paper → Journal of Banking and Finance; DOI SSRN:1932844
- **R2 PASS**: Pure price arithmetic; no external data

## Signal definition (from Neely-Weller 2013, Section II)

```
z_t = +1 if S_t > max(S_{t-1}, ..., S_{t-n}) × (1 + x)   [long]
z_t = -1 if S_t < min(S_{t-1}, ..., S_{t-n}) × (1 - x)   [short]
z_t = z_{t-1}  otherwise  [hold]
```

Where:
- `S_t` = current close price
- n ∈ {5, 10, 20}
- x = 0.001 (0.1% buffer band)

## Entry rules (MQL5 equivalent)

```mql5
// InpLen: channel lookback (default 20; sweep 5, 10, 20)
// InpBand: buffer fraction (default 0.001; sweep 0.0005, 0.001, 0.002)

double S_cur  = iClose(_Symbol, PERIOD_D1, 1);  // latest close
double chanHi = iHighest(_Symbol, PERIOD_D1, MODE_CLOSE, InpLen, 2);  // max of prior n closes
double chanLo = iLowest (_Symbol, PERIOD_D1, MODE_CLOSE, InpLen, 2);  // min of prior n closes

bool longBreak  = (S_cur > chanHi * (1.0 + InpBand));
bool shortBreak = (S_cur < chanLo * (1.0 - InpBand));
```

**LONG**: `longBreak` → enter long; hold until `shortBreak`  
**SHORT**: `shortBreak` → enter short; hold until `longBreak`

This is an always-in-market trend-following system with position changes only on opposite-direction channel breaks.

## Stop loss

Source defines this as an always-in-market system (positions only change direction). Factory adds a safety ATR-based SL:

- **SL**: 3×ATR(14) D1 (wider than typical because this is a trend-following system; 2×ATR may be too tight)

## Exit rules

Primary exit: opposite channel break signal (position flip).  
Safety exit: ATR-based stop loss.

## Parameters to sweep

| Parameter | Default | Sweep |
|-----------|---------|-------|
| `InpLen` | 20 | 5, 10, 20, 40 |
| `InpBand` | 0.001 | 0.0005, 0.001, 0.002, 0.003 |

## Risk

- `RISK_FIXED = 1000` for P2 backtest
- `RISK_PERCENT = 0.5` for live

## Notes

- Neely-Weller (2013) find that channel rules (n=5-20) were most frequently selected in the pre-2000 period; post-2000 the carry trade dominated. Advanced-market-only (major pairs) showed near-zero Sharpe ratios for naively-applied rules in 2000-2012.
- The x=0.001 buffer band is the distinguishing feature of this card vs. standard channel breakout cards (11098, etc.)
- Factory adaptive P3 gate implements the "best rules" selection concept from the paper
- Original testing: 21 major + 19 cross pairs vs USD, 1973-2012 daily data
