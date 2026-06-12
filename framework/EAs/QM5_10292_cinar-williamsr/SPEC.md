# QM5_10292_cinar-williamsr - Strategy Spec

**EA ID:** QM5_10292
**Slug:** cinar-williamsr
**Source:** 1b906e79-c619-5a61-90db-ee19ac95a19f (see `strategy-seeds/sources/1b906e79-c619-5a61-90db-ee19ac95a19f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades Williams %R reversal signals on closed D1 bars. It opens long when Williams %R(14) is at or below -80 and opens short when Williams %R(14) is at or above -20. Existing positions are closed when the opposite threshold appears, allowing the framework to open the new opposite-side market entry on the same closed bar. There is no take profit; each position carries a catastrophic 2.0 x ATR(14) stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_wpr_period` | 14 | 2-200 | Williams %R lookback period. |
| `strategy_long_threshold` | -80.0 | -100.0-0.0 | Long entry and short-exit threshold. |
| `strategy_short_threshold` | -20.0 | -100.0-0.0 | Short entry and long-exit threshold. |
| `strategy_atr_period` | 14 | 2-200 | ATR lookback for catastrophic stop placement. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | ATR multiplier for catastrophic stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major suitable for OHLC range-position oscillators.
- `GBPUSD.DWX` - liquid FX major suitable for OHLC range-position oscillators.
- `XAUUSD.DWX` - liquid metal CFD with swing behaviour compatible with range reversal.
- `GDAXI.DWX` - DWX matrix DAX proxy for the card's DAX target.
- `NDX.DWX` - liquid US index CFD from the card's index basket.
- `WS30.DWX` - liquid US index CFD from the card's index basket.

**Explicitly NOT for:**
- `DAX.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | days |
| Expected drawdown profile | Mean-reversion whipsaw risk during persistent trends, bounded by catastrophic ATR stop. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Source type:** GitHub repository
**Pointer:** https://github.com/cinar/indicator/blob/master/strategy/momentum/williams_r_strategy.go and https://github.com/cinar/indicator/blob/master/momentum/williams_r.go
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10292_cinar-williamsr.md`

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
| v1 | 2026-06-12 | Initial build from card | 965c8404-cc3b-4122-a097-256f7523444b |
