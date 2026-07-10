# QM5_11916_neely-weller-alexander-filter-2pct-d1 - Strategy Spec

**EA ID:** QM5_11916
**Slug:** `neely-weller-alexander-filter-2pct-d1`
**Source:** `7e2b8f4a-3c95-5d68-9a47-d3b6e1f4c7a8`
**Author of this spec:** Codex
**Last revised:** 2026-07-10

---

## 1. Strategy Logic

This EA mechanizes the Alexander 1961 percentage filter rule as described by Neely and Weller. On each closed D1 bar it maintains the running low and running high since the last directional flip. It enters long when the close is greater than `running_low_since_flip * 1.02`, and enters short when the close is less than `running_high_since_flip * 0.98`.

The strategy is intended to be flat only before the first valid trigger. After the first trigger, an opposite filter trigger closes the existing direction and permits the next direction to open. A defensive stop is placed at 4 * ATR(14), and a hard timeout exits after 250 D1 bars if no opposite trigger occurs first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_filter_size_y` | 0.02 | 0.005-0.10 | Percentage reversal filter used for directional turns. |
| `strategy_atr_period` | 14 | 5-50 | D1 ATR lookback for the defensive stop. |
| `strategy_atr_sl_mult` | 4.0 | 1.0-8.0 | ATR multiple used to place the defensive stop. |
| `strategy_time_stop_bars` | 250 | 20-500 | Maximum D1 holding period before a timeout exit. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair covered by the approved card.
- `GBPUSD.DWX` - major FX pair covered by the approved card.
- `USDJPY.DWX` - major FX pair covered by the approved card.
- `USDCAD.DWX` - major FX pair covered by the approved card.
- `USDCHF.DWX` - major FX pair covered by the approved card.
- `AUDUSD.DWX` - major FX pair covered by the approved card.
- `NZDUSD.DWX` - major FX pair covered by the approved card.
- `EURJPY.DWX` - major FX cross covered by the approved card.
- `GBPJPY.DWX` - major FX cross covered by the approved card.
- `AUDJPY.DWX` - major FX cross covered by the approved card.

**Explicitly NOT for:**
- Index, metal, energy, equity, crypto, and rates symbols - not part of the Neely-Weller FX filter test universe used for this card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` on the attached D1 chart |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | About 8 |
| Typical hold time | Days to months |
| Expected drawdown profile | Trend-following filter systems can carry extended adverse moves before a flip or timeout. |
| Regime preference | Trend-following / directional persistence |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `7e2b8f4a-3c95-5d68-9a47-d3b6e1f4c7a8`
**Source type:** paper
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11916_neely-weller-alexander-filter-2pct-d1.md`
**R1-R4 verdict (Q00):** all PASS in the approved card.

Christopher J. Neely and Paul A. Weller, "Lessons from the Evolution of Foreign Exchange Trading Strategies", Federal Reserve Bank of St. Louis Working Paper 2011-021C / SSRN, April 2013, Section 2.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-28 | Q02 infra repair | Added missing spec while repairing magic registration and setfile slots. |
| v2 | 2026-07-10 | Q02 recovery completion | Kept management/exits live through news windows and initialized entry requests before full-basket requeue. |
