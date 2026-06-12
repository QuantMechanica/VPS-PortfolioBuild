# QM5_10287_cinar-ichimoku - Strategy Spec

**EA ID:** QM5_10287
**Slug:** `cinar-ichimoku`
**Source:** `1b906e79-c619-5a61-90db-ee19ac95a19f` (see approved card source links)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA evaluates Ichimoku Cloud values on the close of a D1 bar using fixed 9/26/52 periods. It opens long when close is above both Leading Span A and Leading Span B, the conversion line is above the base line, and Leading Span A is above Leading Span B. It opens short when the inverse condition holds. An open position is closed when the opposite full signal appears, otherwise it remains open unless the framework stop or Friday close exits it.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_tenkan_period` | 9 | 1-200 | Conversion line lookback. |
| `strategy_kijun_period` | 26 | 1-300 | Base line lookback. |
| `strategy_senkou_b_period` | 52 | 1-500 | Leading Span B lookback. |
| `strategy_signal_shift` | 1 | 1-10 | Closed-bar shift used for signal evaluation. |
| `strategy_atr_period` | 14 | 1-200 | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-20.0 | ATR multiplier for the catastrophic stop. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `AUDCAD.DWX` - major FX cross with daily OHLC trend behaviour.
- `AUDCHF.DWX` - major FX cross with daily OHLC trend behaviour.
- `AUDJPY.DWX` - major FX cross with daily OHLC trend behaviour.
- `AUDNZD.DWX` - major FX cross with daily OHLC trend behaviour.
- `AUDUSD.DWX` - major FX major/cross with daily OHLC trend behaviour.
- `CADCHF.DWX` - major FX cross with daily OHLC trend behaviour.
- `CADJPY.DWX` - major FX cross with daily OHLC trend behaviour.
- `CHFJPY.DWX` - major FX cross with daily OHLC trend behaviour.
- `EURAUD.DWX` - major FX cross with daily OHLC trend behaviour.
- `EURCAD.DWX` - major FX cross with daily OHLC trend behaviour.
- `EURCHF.DWX` - major FX cross with daily OHLC trend behaviour.
- `EURGBP.DWX` - major FX cross with daily OHLC trend behaviour.
- `EURJPY.DWX` - major FX cross with daily OHLC trend behaviour.
- `EURNZD.DWX` - major FX cross with daily OHLC trend behaviour.
- `EURUSD.DWX` - major FX major with daily OHLC trend behaviour.
- `GBPAUD.DWX` - major FX cross with daily OHLC trend behaviour.
- `GBPCAD.DWX` - major FX cross with daily OHLC trend behaviour.
- `GBPCHF.DWX` - major FX cross with daily OHLC trend behaviour.
- `GBPJPY.DWX` - card-named FX cross.
- `GBPNZD.DWX` - major FX cross with daily OHLC trend behaviour.
- `GBPUSD.DWX` - major FX major/cross with daily OHLC trend behaviour.
- `GDAXI.DWX` - verified DWX DAX symbol, mapped from card wording `DAX.DWX`.
- `NDX.DWX` - card-named liquid index CFD.
- `NZDCAD.DWX` - major FX cross with daily OHLC trend behaviour.
- `NZDCHF.DWX` - major FX cross with daily OHLC trend behaviour.
- `NZDJPY.DWX` - major FX cross with daily OHLC trend behaviour.
- `NZDUSD.DWX` - major FX major/cross with daily OHLC trend behaviour.
- `USDCAD.DWX` - major FX major with daily OHLC trend behaviour.
- `USDCHF.DWX` - major FX major with daily OHLC trend behaviour.
- `USDJPY.DWX` - major FX major with daily OHLC trend behaviour.
- `WS30.DWX` - card-named liquid index CFD.
- `XAUUSD.DWX` - card-named metal trend instrument.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - no verified DWX data path.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | not stated in card frontmatter |
| Expected drawdown profile | trend-following drawdowns during range-bound cloud churn |
| Regime preference | trend-following |
| Win rate target (qualitative) | not stated in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1b906e79-c619-5a61-90db-ee19ac95a19f`
**Source type:** GitHub repository
**Pointer:** `https://github.com/cinar/indicator`, strategy file `strategy/momentum/ichimoku_cloud_strategy.go`, indicator file `momentum/ichimoku_cloud.go`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10287_cinar-ichimoku.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-12 | Initial build from card | b5358a5a-c1ea-4c4c-8f61-a03c01654036 |
