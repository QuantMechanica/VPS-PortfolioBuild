# QM5_11357_robo-bb-gjpy - Strategy Spec

**EA ID:** QM5_11357
**Slug:** `robo-bb-gjpy`
**Source:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d` (see local RoboForex PDF archive)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades a Bollinger Band mean-reversion setup on M5. It buys when the prior closed bar closes between the lower BB(20, 2.0) and lower BB(20, 3.0), and sells when the prior closed bar closes between the upper BB(20, 2.0) and upper BB(20, 3.0). Trades are skipped when the spread is above 5 pips, outside the 13:00-22:00 GMT London/New York window, or when BB(20, 2.0) width is below 15 pips. Exits are via a 15-pip take profit, a local one-bar stop buffered by 2 pips and capped at 15 pips, plus the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 2-200 | Bollinger Band moving-average period. |
| `strategy_bb_inner_dev` | 2.0 | 0.5-4.0 | Inner Bollinger deviation used for the trigger line. |
| `strategy_bb_outer_dev` | 3.0 | 1.0-5.0 | Outer Bollinger deviation; entries beyond this band are skipped. |
| `strategy_take_profit_pips` | 15 | 1-100 | Fixed take-profit distance in pips. |
| `strategy_stop_cap_pips` | 15 | 1-100 | Maximum stop-loss distance in pips. |
| `strategy_stop_buffer_pips` | 2 | 0-20 | Extra stop buffer beyond the prior bar low/high. |
| `strategy_spread_cap_pips` | 5 | 1-20 | Maximum allowed spread in pips. |
| `strategy_min_bb_width_pips` | 15 | 1-200 | Minimum BB(20, 2.0) width required for trading. |
| `strategy_session_start_gmt` | 13 | 0-23 | GMT hour when entries may begin. |
| `strategy_session_end_gmt` | 22 | 1-24 | GMT hour when entries stop. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` - primary source pair and highest-volatility target for the GBP/JPY Bollinger scalp.
- `GBPUSD.DWX` - P2 portable GBP pair named by the card.
- `USDJPY.DWX` - P2 portable JPY pair named by the card.

**Explicitly NOT for:**
- `SP500.DWX` - equity index behaviour does not match the card's GBPJPY/forex scalp source.
- `XAUUSD.DWX` - metal volatility and spread profile are outside the card's forex-pair scope.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `400` |
| Typical hold time | `minutes to a few M5 bars` |
| Expected drawdown profile | `frequent small losses from capped scalping stops during trend extensions` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `high` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d`
**Source type:** `local PDF`
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\362359657-Robo-forex-strategy.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11357_robo-bb-gjpy.md`

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
| v1 | 2026-06-08 | Initial build from card | f08306ae-f35b-44e6-94ed-dddda176d45d |
