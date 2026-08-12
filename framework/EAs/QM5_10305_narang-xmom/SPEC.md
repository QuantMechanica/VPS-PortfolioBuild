# QM5_10305_narang-xmom - Strategy Spec

**EA ID:** QM5_10305
**Slug:** `narang-xmom`
**Source:** `0f051e46-12b2-51f3-aad5-d6d8bd3e9b35`
**Author of this spec:** Codex
**Last revised:** 2026-07-31

---

## 1. Strategy Logic

On each completed weekly bar, the EA computes the 13-week return of every available instrument in its ten-symbol basket and ranks those returns from strongest to weakest. It buys the chart symbol when it is in the top 30% with a positive return, and sells it when it is in the bottom 30% with a negative return. A position exits when its return changes sign, it leaves the relevant top or bottom 50% rank band, or it has been held for eight weekly bars; the initial stop is three D1 ATRs and an improve-only three-ATR trail is checked weekly after the position reaches +1.5R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_roc_lookback_w1` | 13 | 8-26 | Completed W1 bars used for each instrument's rate of change. |
| `strategy_entry_percentile` | 0.30 | 0.20-0.40 | Fraction of the ranked universe eligible at each extreme for entry. |
| `strategy_exit_percentile` | 0.50 | 0.40-0.60 | Top or bottom rank band a held symbol must remain inside. |
| `strategy_time_exit_w1_bars` | 8 | 6-12 | Maximum W1 bars a position may remain open. |
| `strategy_min_active_symbols` | 8 | 8-10 | Minimum basket members with valid weekly return data. |
| `strategy_atr_period` | 14 | 5-50 | D1 ATR period for stop and trail distance. |
| `strategy_atr_sl_mult` | 3.0 | 1.0-6.0 | D1 ATR multiple for the initial stop. |
| `strategy_trail_atr_mult` | 3.0 | 1.0-6.0 | D1 ATR multiple for the weekly trailing stop. |
| `strategy_trail_trigger_r` | 1.5 | 0.5-3.0 | Open-profit threshold, in original R, before trailing starts. |
| `strategy_spread_atr_cap` | 0.50 | 0.0-1.0 | Maximum quoted spread as a fraction of D1 ATR; zero disables the cap. |

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` - liquid G10 FX member of the cross-asset rank.
- `GBPUSD.DWX` - liquid G10 FX member of the cross-asset rank.
- `USDJPY.DWX` - liquid G10 FX member of the cross-asset rank.
- `AUDUSD.DWX` - liquid G10 FX member of the cross-asset rank.
- `USDCAD.DWX` - liquid G10 FX member of the cross-asset rank.
- `XAUUSD.DWX` - metal diversifier with validated DWX history.
- `GDAXI.DWX` - canonical validated DAX proxy; this is the DWX-matrix port of the card's `DE40.DWX` label.
- `NDX.DWX` - US growth-equity index member of the rank.
- `WS30.DWX` - US large-cap equity index member of the rank.
- `XTIUSD.DWX` - crude-oil member that adds energy exposure beyond natural gas.

**Explicitly NOT for:**

- Crypto instruments - none is present in the validated DWX symbol matrix for this build.
- Rates or bond instruments - no approved DWX rates feed is registered for this card.
- `SP500.DWX` - not part of the approved initial basket and unnecessary for the registered ten-symbol implementation.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `W1` |
| Multi-timeframe refs | W1 closes across the full basket; D1 ATR(14) on the chart symbol |
| Bar gating | `QM_IsNewBar()` for entries; weekly state cached through `QM_CalendarPeriodKey(PERIOD_W1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 20 card-estimate opportunities, with realized entries dependent on cross-sectional rank |
| Typical hold time | One to eight weeks |
| Expected drawdown profile | Moderate trend-following drawdowns with clustered losses during sharp macro reversals |
| Regime preference | Persistent cross-asset relative trends |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0f051e46-12b2-51f3-aad5-d6d8bd3e9b35`
**Source type:** `book`
**Pointer:** Rishi K. Narang, *Inside the Black Box*, Wiley; O'Reilly chapter preview at `https://www.oreilly.com/library/view/inside-the-black/9780470432068/9780470432068_blending_alpha_models.html`
**R1-R4 verdict (Q00):** R1 lineage recorded and R2-R4 PASS per `artifacts/cards_approved/QM5_10305_narang-xmom.md`.

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
| v1 | 2026-07-31 | Initial build from approved card | farm task 40043f73-547c-4168-b987-03cf92079125 |
