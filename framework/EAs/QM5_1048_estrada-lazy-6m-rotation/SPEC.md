# QM5_1048_estrada-lazy-6m-rotation - Strategy Spec

**EA ID:** QM5_1048
**Slug:** `estrada-lazy-6m-rotation`
**Source:** `afab7a6f-c3c8-51ae-a609-f376744beb8e` (see `strategy-seeds/sources/afab7a6f-c3c8-51ae-a609-f376744beb8e/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

On the first D1 bar after June or December month-end, the EA ranks the four registered DWX index symbols by trailing six-month D1 close-to-close return. It buys the top two symbols and skips the rest. Existing positions are closed once at each semi-annual rebalance so the next top-two basket can be entered from scratch. The baseline does not use the optional absolute-momentum overlay, and a 20% equity drawdown overlay closes the current symbol if tripped.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_d1_bars` | 126 | `1+` | D1 bars used as the six-month trailing return proxy. |
| `strategy_top_n` | 2 | `1-4` | Number of ranked symbols to hold from the four-symbol universe. |
| `strategy_atr_period` | 14 | `1+` | D1 ATR period for the hard stop overlay. |
| `strategy_atr_sl_mult` | 4.0 | `>0` | ATR multiplier for the stop loss. |
| `strategy_absolute_momentum` | false | `true/false` | Optional P3 overlay; baseline false per card. |
| `strategy_max_spread_points` | 0 | `0+` | Optional spread gate; zero disables it for the baseline. |
| `strategy_portfolio_max_dd_pct` | 20.0 | `0+` | Portfolio drawdown trip level; zero disables it. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index exposure from the card's DWX-available subset.
- `WS30.DWX` - Dow 30 index exposure from the card's DWX-available subset.
- `GDAXI.DWX` - DAX 40 index exposure from the card's DWX-available subset.
- `UK100.DWX` - FTSE 100 index exposure from the card's DWX-available subset.

**Explicitly NOT for:**
- `SP500.DWX` - not in the card's final four-symbol R3 subset for this EA.
- Forex, metals, and energy `.DWX` symbols - outside the country-index rotation universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `2` |
| Typical hold time | roughly six months |
| Expected drawdown profile | index-momentum drawdowns with ATR hard-stop protection and portfolio kill-switch overlay |
| Regime preference | cross-sectional trend / momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `afab7a6f-c3c8-51ae-a609-f376744beb8e`
**Source type:** paper
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1048_estrada-lazy-6m-rotation.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_1048_estrada-lazy-6m-rotation.md`

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
| v1 | 2026-06-13 | Initial build from card | b4eb8b35-0381-46dc-afff-20fc7f4b6185 |
