# QM5_11721_tc-m5-s7-london-box-breakout — Strategy Spec

**EA ID:** QM5_11721
**Slug:** `tc-m5-s7-london-box-breakout`
**Source:** `40a4454c-64ff-5015-8538-9f7b32abc0e9` (see `sources/tc-20-forex-strategies-m5-367145560`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

At 15:00 DWX broker time, the EA builds a one-hour box from the high and low of the prior twelve M5 bars whose broker open time is 14:00-14:55. During the next hour, it buys when the just-closed M5 close is above `box_high + 0.20 * box_height`, or sells when the close is below `box_low - 0.20 * box_height`. Long trades use the box low as stop and `box_high + 4.0 * box_height` as take profit; short trades use the box high as stop and `box_low - 4.0 * box_height` as take profit. While a trade is open, the stop trails by one box height from the favorable tick extreme.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_box_hour_broker` | 14 | 0-23 | Broker-time hour used to build the prior-hour box. |
| `strategy_entry_hour_broker` | 15 | 0-23 | Broker-time hour when breakout signals become valid. |
| `strategy_expiry_hour_broker` | 16 | 0-23 | Broker-time hour when new breakout entries stop. |
| `strategy_box_bars` | 12 | 1-24 | M5 bars scanned for the one-hour box. |
| `strategy_breakout_fraction` | 0.20 | 0.0-1.0 | Fraction of box height required beyond the box edge. |
| `strategy_take_profit_box_mult` | 4.0 | 0.1-10.0 | Take-profit distance as a multiple of box height from the broken edge. |
| `strategy_max_spread_pips` | 15.0 | 0.0-100.0 | Blocks only genuinely wide nonzero spread; zero modeled DWX spread remains tradable. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` — explicitly named by the card as a volatile GBP pair for the M5 session-box breakout.
- `GBPUSD.DWX` — explicitly named by the card as a volatile GBP pair for the M5 session-box breakout.

**Explicitly NOT for:**
- `EURUSD.DWX` — not part of the card's GBP-pair universe.
- `XAUUSD.DWX` — different session volatility structure and not cited by the card.
- `SP500.DWX` — index CFD, not a GBP FX pair.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `250` |
| Typical hold time | Intraday; minutes to a few hours, bounded by TP/SL/trailing behaviour. |
| Expected drawdown profile | Breakout whipsaws cluster in quiet London-open sessions. |
| Regime preference | Volatility-expansion breakout |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `40a4454c-64ff-5015-8538-9f7b32abc0e9`
**Source type:** book
**Pointer:** `sources/tc-20-forex-strategies-m5-367145560`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11721_tc-m5-s7-london-box-breakout.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-20 | Initial build from card | 6f81cb83-d6b1-40c2-bb38-92ab058539bc |
