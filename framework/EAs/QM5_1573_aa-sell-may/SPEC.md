# QM5_1573_aa-sell-may - Strategy Spec

**EA ID:** QM5_1573
**Slug:** aa-sell-may
**Source:** ede348b4-0fa7-5be1-baa8-09e9089b67b7
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

The EA implements the Alpha Architect Sell-in-May seasonal rule as a long-only index timing strategy. It enters long exposure on the first tradable D1 bar in November, representing the next-bar-open execution after the final October trading day. It stays long through November, December, January, February, March, and April, then closes any open position during the May through October cash window. The initial protective stop is set at 3.0 times ATR(20) on D1, and no short side is used.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_entry_month | 11 | 1-12 | Calendar month in which the seasonal long entry is allowed. |
| strategy_exit_month | 5 | 1-12 | First calendar month of the flat/cash season. |
| strategy_entry_window_days | 7 | 1-31 | Latest calendar day in November allowed for the first tradable entry bar. |
| strategy_min_daily_bars | 260 | 1+ | Minimum D1 history required before the strategy may trade. |
| strategy_atr_period_d1 | 20 | 1+ | ATR lookback on D1 for the initial stop. |
| strategy_atr_sl_mult | 3.0 | greater than 0 | ATR multiple used for the initial stop. |
| strategy_max_spread_points | 0 | 0+ | Optional maximum spread in points; 0 disables the cap and permits zero modeled DWX spread. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - source-faithful S&P 500 validation target; backtest-only custom symbol.
- NDX.DWX - live-tradable US large-cap technology index proxy for parallel validation.
- WS30.DWX - live-tradable US large-cap Dow index proxy for parallel validation.

**Explicitly NOT for:**
- Forex, metals, energy, and non-index DWX symbols - the card is an equity-index seasonality rule, not a cross-asset timing rule.
- SPX500.DWX, SPY.DWX, and ES.DWX - not canonical DWX matrix symbols for the S&P 500.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 from card frontmatter; mechanical seasonal body implies about 1 new entry per year before stop exits |
| Expected trade frequency | Not specified in frontmatter; seasonal annual entry cadence inferred from the card mechanics |
| Typical hold time | Up to about 6 months, November through April |
| Expected drawdown profile | Equity-index seasonal exposure with ATR stop protection during the long season |
| Regime preference | Equity bullish/seasonal November-April window |
| Win rate target | Not specified |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ede348b4-0fa7-5be1-baa8-09e9089b67b7
**Source type:** blog
**Pointer:** Wesley Gray, PhD, "We are in May-Should we Sell and Go Away?", Alpha Architect, 2014-05-01, https://alphaarchitect.com/may-sell-go-away/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1573_aa-sell-may.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-30 | Initial build from card | c777b63d-d31e-4f48-b59d-11f7cbebe2ab |
