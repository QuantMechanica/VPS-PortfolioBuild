# QM5_9985_tv-mes-mr-ema9-200ma - Strategy Spec

**EA ID:** QM5_9985
**Slug:** tv-mes-mr-ema9-200ma
**Source:** 30591366-874b-5bee-b47c-da2fca20b728 (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades long-only M30 equity-index mean reversion. On each closed M30 bar it reads EMA(9) and SMA(200); a long signal fires when EMA(9) is at or below SMA(200), the prior closed-bar EMA slope was negative, and the just-closed EMA slope has turned non-negative. The trade opens at market on the next bar with an 8 source-point stop, a 20 source-point final take-profit, partial closes at +6 and +10 source-points, a breakeven stop after TP1, and a +5 source-point locked stop after TP2.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 9 | 2-50 | Fast EMA period used for pullback and slope-flip detection. |
| `strategy_sma_period` | 200 | 50-400 | Slow SMA regime line; entry requires EMA at or below this value. |
| `strategy_point_unit` | 1.0 | >0 | Price distance represented by one card source-point. |
| `strategy_tp1_points` | 6.0 | >0 | First partial-close trigger in source-points. |
| `strategy_tp2_points` | 10.0 | >0 | Second partial-close trigger in source-points. |
| `strategy_tp3_points` | 20.0 | >0 | Final take-profit distance in source-points. |
| `strategy_sl_points` | 8.0 | >0 | Initial stop-loss distance in source-points. |
| `strategy_lock_points` | 5.0 | >=0 | Stop level after TP2, measured above entry in source-points. |
| `strategy_cooldown_bars` | 6 | 0-50 | Minimum M30 bars after a signal before another signal is allowed. |
| `strategy_rth_only` | false | true/false | Optional RTH-only session filter for P3 sweeps; default is continuous trading per source. |
| `strategy_rth_start_hhmm` | 1530 | 0-2359 | Broker-time RTH start when the optional session filter is enabled. |
| `strategy_rth_end_hhmm` | 2200 | 0-2359 | Broker-time RTH end when the optional session filter is enabled. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - Backtest analog for the source MES S&P 500 strategy.
- `NDX.DWX` - DWX large-cap US index exposure suitable for live-tradable validation.
- `WS30.DWX` - DWX large-cap US index exposure suitable for live-tradable validation.

**Explicitly NOT for:**
- Non-index FX, metals, or energy symbols - the card is calibrated to M30 US equity-index pullbacks.
- Unavailable S&P variants such as `SPX500.DWX`, `SPY.DWX`, or `ES.DWX` - the canonical DWX symbol is `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Not stated in frontmatter; intraday M30 trade, normally minutes to hours until TP3 or stop transition. |
| Expected drawdown profile | Bounded by the initial 8 source-point stop before TP1; residual risk reduced after TP1 and TP2. |
| Regime preference | Mean-reversion pullback under a long moving-average regime line. |
| Win rate target (qualitative) | Medium to high, inferred from selective slope-flip mean reversion. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView script
**Pointer:** https://www.tradingview.com/script/ERAn3ljA-Mean-Reversion-at-or-under-200MA/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9985_tv-mes-mr-ema9-200ma.md`

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
| v1 | 2026-06-20 | Initial build from card | eff80ae5-e9f6-4ad7-8dd5-04ea6614ea6f |
