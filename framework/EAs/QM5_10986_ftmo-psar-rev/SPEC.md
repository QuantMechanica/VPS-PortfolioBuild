# QM5_10986_ftmo-psar-rev - Strategy Spec

**EA ID:** QM5_10986
**Slug:** ftmo-psar-rev
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades Parabolic SAR reversals on H1. A long entry requires the SAR dot to flip from above price to below price on the latest closed bar, with price above EMA(100) or EMA(100) rising over 10 bars, and a candle body of at least 0.35 x ATR(14). A short entry uses the inverse SAR flip and EMA trend condition. Initial stop loss combines the current SAR value with a 1.2 x ATR stop leg, the take profit is 2.0R, the stop trails to SAR after a 1.0R touch, and positions close on an opposite SAR flip or after 40 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sar_step` | 0.02 | 0.001-0.20 | Parabolic SAR acceleration step. |
| `strategy_sar_max` | 0.20 | 0.01-1.00 | Parabolic SAR maximum acceleration. |
| `strategy_ema_period` | 100 | 20-300 | Trend filter EMA period on H1. |
| `strategy_ema_slope_bars` | 10 | 2-50 | Bars used to decide whether EMA(100) is rising or falling. |
| `strategy_atr_period` | 14 | 5-50 | ATR period for volatility filter and stop sizing. |
| `strategy_body_atr_frac` | 0.35 | 0.05-2.00 | Minimum closed candle body as a fraction of ATR(14). |
| `strategy_atr_pct_lookback` | 250 | 50-500 | ATR history length used for the percentile floor. |
| `strategy_atr_pct_floor` | 20.0 | 0.0-50.0 | Skip entries when ATR rank is below this percentile. |
| `strategy_sl_atr_mult` | 1.2 | 0.25-5.00 | ATR leg used in the initial stop rule. |
| `strategy_sl_max_atr_mult` | 2.5 | 0.50-10.00 | Maximum allowed stop distance as a multiple of ATR. |
| `strategy_tp_rr` | 2.0 | 0.50-10.00 | Take profit in initial-risk multiples. |
| `strategy_trail_trigger_r` | 1.0 | 0.25-5.00 | Start SAR trailing after price reaches this R multiple. |
| `strategy_time_exit_bars` | 40 | 1-200 | Time exit measured in H1 bars. |
| `strategy_spread_median_bars` | 20 | 1-100 | Closed-bar spread lookback for the spread filter. |
| `strategy_spread_median_mult` | 1.5 | 0.5-10.0 | Skip when current spread exceeds this multiple of median spread. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed DWX major FX pair with native OHLC support.
- `GBPUSD.DWX` - card-listed DWX major FX pair with native OHLC support.
- `XAUUSD.DWX` - card-listed DWX metal CFD with native OHLC support.
- `GDAXI.DWX` - registered as the canonical DWX DAX instrument for the card's `GER40.DWX` exposure.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; DAX exposure is mapped to `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Intraday to about 40 H1 bars, capped by the time exit. |
| Expected drawdown profile | Trend-reversal entries with ATR-capped initial risk and 2.0R target. |
| Regime preference | Trend-following reversal after PSAR flip, with volatility expansion. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** article
**Pointer:** FTMO, "Top 11 Technical Indicators That Can Change Your Trading Forever", 2019, https://ftmo.com/en/blog/technical-indicators/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10986_ftmo-psar-rev.md`

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
| v1 | 2026-06-18 | Initial build from card | 13a19eef-1256-4c3d-a13b-b1356a3f16df |
