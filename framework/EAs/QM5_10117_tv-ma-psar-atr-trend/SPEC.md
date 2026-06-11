# QM5_10117_tv-ma-psar-atr-trend - Strategy Spec

**EA ID:** QM5_10117
**Slug:** tv-ma-psar-atr-trend
**Source:** 30591366-874b-5bee-b47c-da2fca20b728 (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades the H1 trend state from a fast EMA(20) and slow EMA(50). It enters long when the fast EMA is above the slow EMA, the last closed price is above the fast EMA, and PSAR is below price; it enters short on the inverse conditions. The initial stop is 2 times ATR(14) from entry. It exits long when the fast EMA falls below the slow EMA or PSAR moves above price, and exits short when the fast EMA rises above the slow EMA or PSAR moves below price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_H1` | MT5 timeframe enum | Timeframe used for EMA, PSAR, and ATR reads. |
| `strategy_fast_ema_period` | `20` | `> 1` | Fast EMA period for trend state and price relation. |
| `strategy_slow_ema_period` | `50` | `> strategy_fast_ema_period` | Slow EMA period for trend state. |
| `strategy_psar_step` | `0.02` | `> 0` | Parabolic SAR step. |
| `strategy_psar_maximum` | `0.20` | `> strategy_psar_step` | Parabolic SAR maximum. |
| `strategy_atr_period` | `14` | `> 0` | ATR period for stop distance and spread filter. |
| `strategy_atr_stop_mult` | `2.0` | `> 0` | ATR multiplier for initial stop loss. |
| `strategy_max_spread_stop_pct` | `0.10` | `>= 0` | Blocks new trades when spread exceeds this fraction of the ATR stop distance. |
| `strategy_longs_enabled` | `true` | boolean | Enables long entries. |
| `strategy_shorts_enabled` | `true` | boolean | Enables short entries. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed major FX symbol with direct DWX availability.
- `GBPUSD.DWX` - Card-listed major FX symbol with direct DWX availability.
- `XAUUSD.DWX` - Card-listed gold CFD symbol with direct DWX availability.
- `GDAXI.DWX` - DWX matrix DAX symbol used for the card's German index exposure.

**Explicitly NOT for:**
- `GER40.DWX` - Card-stated name is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the available DAX port.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `36` |
| Typical hold time | hours to days |
| Expected drawdown profile | ATR stop limits each trade; drawdowns are expected during sideways regimes. |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView public script
**Pointer:** https://www.tradingview.com/script/Ixc6wuA0-2-Moving-Averages-Trend-Following/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10117_tv-ma-psar-atr-trend.md`

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
| v1 | 2026-06-12 | Initial build from card | c79f817c-928f-4ade-b7cc-cc164a449002 |
