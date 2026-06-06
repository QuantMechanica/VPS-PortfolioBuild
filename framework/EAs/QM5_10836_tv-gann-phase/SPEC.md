# QM5_10836_tv-gann-phase - Strategy Spec

**EA ID:** QM5_10836
**Slug:** `tv-gann-phase`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades the M30 baseline from the card. On each closed bar it finds recent automatic pivot highs and lows, measures the swing angle after normalising the pivot-to-pivot slope by ATR(14), and classifies the phase as ACCUM, MODER, EXPAN, or ACCEL. The Medium baseline enters long when the swing is bullish, the phase is MODER or stronger, EMA(8) is above EMA(21), and the closed candle is bullish; it enters short on the inverse bearish conditions. Exits are only the initial ATR stop, a 2.0R fixed target, and framework close gates.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_pivot_lookback` | 5 | 5-20 | Left/right bars required for an automatic pivot high or low. |
| `strategy_pivot_scan_bars` | 50 | 20-200 | Closed-bar search depth for the most recent pivots. |
| `strategy_atr_period` | 14 | 5-50 | ATR period used for phase angle normalisation and stop distance. |
| `strategy_ema_fast` | 8 | 2-50 | Fast EMA confirmation period. |
| `strategy_ema_slow` | 21 | 5-100 | Slow EMA confirmation period. |
| `strategy_angle_weak_deg` | 5.0 | 1.0-20.0 | Boundary below which the phase is ACCUM. |
| `strategy_angle_expansion_deg` | 15.0 | 5.0-40.0 | Boundary between MODER and EXPAN. |
| `strategy_angle_accel_deg` | 30.0 | 10.0-60.0 | Boundary between EXPAN and ACCEL. |
| `strategy_atr_sl_mult` | 1.5 | 1.0-2.0 | ATR multiple for the initial stop. |
| `strategy_tp_rr` | 2.0 | 1.5-3.0 | Fixed take-profit multiple of initial risk. |
| `strategy_entry_mode` | ENTRY_MEDIUM | ENTRY_EASY, ENTRY_MEDIUM, ENTRY_STRICT | Phase gate mode from the card. |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - DAX proxy for the card's `GER40.DWX`, which is not in the matrix.
- `NDX.DWX` - liquid index CFD from the card's R3 basket.
- `XAUUSD.DWX` - liquid metal CFD from the card's R3 basket.
- `EURUSD.DWX` - major FX pair from the card's R3 basket.
- `GBPUSD.DWX` - major FX pair from the card's R3 basket.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated name is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is used instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 75 |
| Typical hold time | Not specified in card; bracket exit implies intraday to multi-day holds. |
| Expected drawdown profile | Directional phase/momentum strategy with parameter sensitivity and noisy pivot-anchor risk. |
| Regime preference | Trend-following / volatility-expansion phases. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script `Gann Fan v15 [Phases + Signals]`, author handle `TagsTrading`, May 4.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10836_tv-gann-phase.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | 45852890-bc3b-4c71-8bd1-123a864881a5 |
