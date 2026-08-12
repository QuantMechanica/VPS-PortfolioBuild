# QM5_11497_connors-alvarez-double7s-sma200-d1 — Strategy Spec

**EA ID:** QM5_11497
**Slug:** `connors-alvarez-double7s-sma200-d1`
**Source:** `e2807d63-4109-5824-8d44-1800ee8fe7eb` (see `[[sources/connors-alvarez-short-term-trading-strategies-2009]]`)
**Author of this spec:** Codex
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

On each closed D1 bar, the EA buys when the close is above SMA(200) and is the lowest close of the latest seven closed bars. It sells the mirror condition when the close is below SMA(200) and is the highest close of those seven bars. A long exits at a seven-bar highest close, a short exits at a seven-bar lowest close, and either side exits after ten held D1 bars; every entry also carries a two-times-ATR(14) stop and is skipped when that stop exceeds 100 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sma_period` | 200 | 100 / 200 / 300 | SMA trend-filter period; P3 card sweep values shown. |
| `strategy_extreme_lookback` | 7 | 5 / 7 / 10 | Number of closed D1 closes used for entry and exit extremes. |
| `strategy_atr_period` | 14 | 14 (card fixed) | ATR period for the protective stop. |
| `strategy_sl_atr_mult` | 2.0 | 1.5 / 2.0 / 3.0 | ATR multiplier applied to the protective stop. |
| `strategy_max_sl_pips` | 100 | 100 (card cap) | Skip an entry whose ATR stop is wider than this pip distance. |
| `strategy_max_hold_bars` | 10 | 7 / 10 / 15 | Maximum number of held D1 bars; P3 card sweep values shown. |
| `strategy_spread_cap_pips` | 30 | 30 (card fixed) | Skip a new entry only when the positive modeled spread exceeds this cap. |

> Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid D1 FX pair explicitly named by the approved card.
- `GBPUSD.DWX` — liquid D1 FX pair explicitly named by the approved card.
- `USDJPY.DWX` — liquid D1 FX pair explicitly named by the approved card.
- `AUDUSD.DWX` — liquid D1 FX pair explicitly named by the approved card.
- `USDCAD.DWX` — liquid D1 FX pair explicitly named by the approved card.

**Explicitly NOT for:**

- Other `.DWX` symbols — the current approved card authorizes only the five-pair FX portability basket above.
- `SP500.DWX` — the original source tested SPY, but this approved implementation is the card's stated Forex adaptation.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` in the canonical skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 (card frontmatter) |
| Expected trade frequency | About two trades per month, derived mechanically from 25 per year. |
| Typical hold time | One to ten D1 bars; the framework Friday-close rule may shorten a hold. |
| Expected drawdown profile | Each trade has a 2×ATR(14) stop capped at 100 pips; the card gives no portfolio drawdown target. |
| Regime preference | Short-term mean reversion inside an SMA(200)-defined directional trend. |
| Win rate target (qualitative) | Not specified by the card. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e2807d63-4109-5824-8d44-1800ee8fe7eb`
**Source type:** book
**Pointer:** `[[sources/connors-alvarez-short-term-trading-strategies-2009]]`, chapter “Double 7's Strategy”
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11497_connors-alvarez-double7s-sma200-d1.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-10 | Initial build from card | 2272a7db-eb02-418c-b165-41450a018f88 |
