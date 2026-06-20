# QM5_11728_tc-m5-s16-wma-psar-adx - Strategy Spec

**EA ID:** QM5_11728
**Slug:** tc-m5-s16-wma-psar-adx
**Source:** 40a4454c-64ff-5015-8538-9f7b32abc0e9 (see `strategy-seeds/sources/40a4454c-64ff-5015-8538-9f7b32abc0e9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades a 5-minute trend-following scalp. Long entries require WMA(5) above SMA(11), Parabolic SAR below the last closed M5 close, and DI+(14) above DI-(14). Short entries require WMA(5) below SMA(11), Parabolic SAR above the last closed M5 close, and DI-(14) above DI+(14). Stops use the recent M5 structure high or low, with a hard 2R take-profit; open trades close when SAR flips to the opposite side or the WMA/SMA pair crosses back.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_wma_period` | 5 | 1+ | Weighted moving average period for trend bias. |
| `strategy_sma_period` | 11 | 1+ | Simple moving average period for trend bias. |
| `strategy_sar_step` | 0.10 | >0 | Parabolic SAR step from the approved card. |
| `strategy_sar_maximum` | 0.01 | >0 | Parabolic SAR maximum from the approved card. |
| `strategy_adx_period` | 14 | 1+ | ADX DI period used for DI+/DI- direction confirmation. |
| `strategy_structure_lookback` | 6 | 1+ | M5 lookback used by `QM_StopStructure` for recent swing high or low stops. |
| `strategy_take_profit_rr` | 2.0 | >0 | Factory safety take-profit as a multiple of stop distance. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with M5 DWX data.
- `GBPUSD.DWX` - card-listed major FX pair with M5 DWX data.
- `USDJPY.DWX` - card-listed major FX pair with M5 DWX data.
- `USDCHF.DWX` - card-listed major FX pair with M5 DWX data.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the source strategy is a 5-minute forex scalp and the approved card lists only FX majors.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Typical hold time | Intraday M5 scalp, minutes to hours |
| Expected drawdown profile | Frequent small losses controlled by structure stops and fixed 2R target |
| Regime preference | Trend-following |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 40a4454c-64ff-5015-8538-9f7b32abc0e9
**Source type:** PDF / strategy collection
**Pointer:** `367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`, Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", Strategy #16, 2013.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11728_tc-m5-s16-wma-psar-adx.md`

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
| v1 | 2026-06-20 | Initial build from card | 463829e8-5e02-46b6-be00-ecbe719275d8 |
