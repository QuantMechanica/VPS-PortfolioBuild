# QM5_11700_ciurea-inv-hammer-star-m30 - Strategy Spec

**EA ID:** QM5_11700
**Slug:** ciurea-inv-hammer-star-m30
**Source:** da47c347-2bdd-5f2a-b019-d400c96d1c7e (see `sources/scientific-forex-ciurea`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA checks the most recently closed M30 candle for the Ciurea long-upper-wick reversal shape. The signal is valid when `UpperWick >= 2 * Body`, `LowerWick <= Body`, and `Body > 0`, where body is `abs(Open[1] - Close[1])`. A bullish or neutral signal opens long as an inverted hammer; a bearish signal opens short as a shooting star. Long stops use the low of the last 3 closed bars minus 3 points, short stops use the high of the last 3 closed bars plus 3 points, and take profit is fixed at 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sl_lookback_bars` | 3 | fixed at 3 | Number of closed bars used to find the stop-loss swing extreme from the card. |
| `strategy_stop_buffer_pts` | 3.0 | >= 0 | Point buffer beyond the three-bar swing extreme. |
| `strategy_min_upper_body_x` | 2.0 | > 0 | Minimum upper-wick multiple of the real body. |
| `strategy_max_lower_body_x` | 1.0 | >= 0 | Maximum lower-wick multiple of the real body. |
| `strategy_reward_risk` | 2.0 | > 0 | Take-profit multiple of initial stop distance. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - explicitly named in the approved card and available in the DWX symbol matrix.
- `GBPUSD.DWX` - explicitly named in the approved card and available in the DWX symbol matrix.

**Explicitly NOT for:**
- Non-FX symbols - the card source and target universe are EURUSD/GBPUSD M30 candlestick tests, not indices, metals, or energy CFDs.

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
| Trades / year / symbol | 60 |
| Typical hold time | Not specified in card; exit is by SL or 2R TP. |
| Expected drawdown profile | Not specified in card; fixed 2R payoff with swing-stop risk. |
| Regime preference | Candlestick reversal / price-action reversal. |
| Win rate target (qualitative) | Not specified in card. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** da47c347-2bdd-5f2a-b019-d400c96d1c7e
**Source type:** scientific-forex report / local archive
**Pointer:** Cristina Ciurea, "Inverted Hammer & Shooting Star Backtest Results", in *The Truth Behind Commonly Used Indicators*, ScientificForex.com.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11700_ciurea-inv-hammer-star-m30.md`

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
| v1 | 2026-06-11 | Initial build from card | 8c28287a-a6a3-49aa-96f1-d3f4f1cbe24a |
