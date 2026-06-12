# QM5_10288_cinar-aroon - Strategy Spec

**EA ID:** QM5_10288
**Slug:** `cinar-aroon`
**Source:** `1b906e79-c619-5a61-90db-ee19ac95a19f` (see approved card source links)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA evaluates Aroon direction on the close of a D1 bar using the source default period of 25 bars. Aroon Up is higher when the most recent 25-bar high is more recent than the most recent 25-bar low; Aroon Down is higher for the inverse condition. The EA opens long when Aroon Up is greater than Aroon Down and opens short when Aroon Down is greater than Aroon Up. An existing position is closed when the opposite Aroon dominance appears, otherwise it remains open unless the catastrophic ATR stop or framework Friday close exits it.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_aroon_period` | 25 | 2-500 | Lookback used to find the most recent high and low for Aroon Up/Down. |
| `strategy_signal_shift` | 1 | 1-10 | Closed-bar shift used for Aroon signal evaluation. |
| `strategy_atr_period` | 14 | 1-200 | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-20.0 | ATR multiplier for the catastrophic stop. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `AUDCAD.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `AUDCHF.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `AUDJPY.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `AUDNZD.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `AUDUSD.DWX` - verified DWX FX major with daily OHLC trend behaviour.
- `CADCHF.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `CADJPY.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `CHFJPY.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `EURAUD.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `EURCAD.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `EURCHF.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `EURGBP.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `EURJPY.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `EURNZD.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `EURUSD.DWX` - verified DWX FX major with daily OHLC trend behaviour.
- `GBPAUD.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `GBPCAD.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `GBPCHF.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `GBPJPY.DWX` - card-named FX cross.
- `GBPNZD.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `GBPUSD.DWX` - verified DWX FX major with daily OHLC trend behaviour.
- `GDAXI.DWX` - verified DWX DAX symbol, mapped from card wording `DAX.DWX`.
- `NDX.DWX` - card-named liquid index CFD.
- `NZDCAD.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `NZDCHF.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `NZDJPY.DWX` - verified DWX FX cross with daily OHLC trend behaviour.
- `NZDUSD.DWX` - verified DWX FX major with daily OHLC trend behaviour.
- `SP500.DWX` - verified S&P 500 custom symbol for backtest-only index coverage.
- `UK100.DWX` - verified DWX index CFD with daily OHLC trend behaviour.
- `USDCAD.DWX` - verified DWX FX major with daily OHLC trend behaviour.
- `USDCHF.DWX` - verified DWX FX major with daily OHLC trend behaviour.
- `USDJPY.DWX` - verified DWX FX major with daily OHLC trend behaviour.
- `WS30.DWX` - card-named liquid index CFD.
- `XAGUSD.DWX` - verified DWX metal with daily OHLC trend behaviour.
- `XAUUSD.DWX` - card-named metal trend instrument.
- `XNGUSD.DWX` - verified DWX energy CFD with daily OHLC trend behaviour.
- `XTIUSD.DWX` - verified DWX energy CFD with daily OHLC trend behaviour.

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
| Trades / year / symbol | 30 |
| Typical hold time | not stated in card frontmatter |
| Expected drawdown profile | trend-following whipsaw risk during range-bound high/low recency flips |
| Regime preference | trend-following / breakout-recency |
| Win rate target (qualitative) | not stated in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1b906e79-c619-5a61-90db-ee19ac95a19f`
**Source type:** GitHub repository
**Pointer:** `https://github.com/cinar/indicator`, strategy file `strategy/trend/aroon_strategy.go`, indicator file `trend/aroon.go`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10288_cinar-aroon.md`

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
| v1 | 2026-06-12 | Initial build from card | 150155e2-a9e9-468d-990d-5686d2b285ee |
