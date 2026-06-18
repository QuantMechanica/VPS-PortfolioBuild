# QM5_11359_robo-adx-mom — Strategy Spec

**EA ID:** QM5_11359
**Slug:** `robo-adx-mom`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (RoboForex strategy collection, "Strategy ADX and Momentum")
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

An M5 trend-strength scalper on liquid FX majors. The single entry EVENT is a fresh
Directional-Index dominance flip on the just-closed bar: long when +DI crosses above
-DI (+DI@2 ≤ -DI@2 and +DI@1 > -DI@1), short when -DI crosses above +DI. Per the build
NOTE and the .DWX two-cross-same-bar trap, only this one cross is the trigger — ADX
strength, the dominant-DI floor, the Momentum regime, Parabolic SAR side, and the EMA
filter are confirming STATES read on the same closed bar, never a second same-bar cross.

A long confirms when ADX(14) > 25, +DI > 25, Momentum(14) > 100, the SAR dot is below
the close, and (filter on) close > EMA(55); the short side is the mirror. Stop and target
are fixed pip distances (7 SL / 15 TP baseline), scale-corrected per symbol digits. The
position exits early if the opposite DI becomes dominant or Momentum crosses back through
100 against the trade; otherwise it runs to SL/TP or the framework Friday-close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_adx_period` | 14 | 7-30 | ADX / +DI / -DI period |
| `strategy_adx_threshold` | 25.0 | 15-40 | ADX strength floor (trend regime on) |
| `strategy_di_threshold` | 25.0 | 15-40 | Minimum value of the dominant DI |
| `strategy_mom_period` | 14 | 7-30 | Momentum period (iMomentum oscillates ~100) |
| `strategy_mom_band` | 0.0 | 0-2 | Band around 100 for the Momentum state (0 = strict) |
| `strategy_sar_step` | 0.02 | 0.01-0.05 | Parabolic SAR acceleration step |
| `strategy_sar_max` | 0.2 | 0.1-0.4 | Parabolic SAR maximum acceleration |
| `strategy_ema_filter_enabled` | true | true/false | Enable EMA trend-context filter (baseline ON) |
| `strategy_ema_period` | 55 | 20-200 | EMA trend-context period |
| `strategy_sl_pips` | 7 | 5-15 | Stop-loss distance in pips |
| `strategy_tp_pips` | 15 | 10-20 | Take-profit distance in pips |
| `strategy_spread_cap_pips` | 1.5 | 0.5-5 | Skip entry only if spread wider than this (fail-open) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deepest-liquidity major; tight spread suits a 7/15-pip scalper.
- `GBPUSD.DWX` — liquid major with stronger intraday trends for the DI/ADX edge.
- `USDJPY.DWX` — liquid JPY major; pip scaling handled via pip-factor conversion.
- `AUDUSD.DWX` — liquid commodity major, adds non-EUR/USD diversification.
- `EURJPY.DWX` — liquid EUR cross with pronounced trend legs, good ADX context.

**Explicitly NOT for:**
- Index / metal / energy `.DWX` symbols — the 7/15-pip stop scaling and FX-session
  assumptions do not transfer to index/CFD point structures.

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
| Trades / year / symbol | `~100` |
| Typical hold time | `minutes to a few hours` |
| Expected drawdown profile | `frequent small losses, fixed 7-pip risk per trade` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book` (strategy collection PDF)
**Pointer:** RoboForex strategy collection, "Strategy ADX and Momentum" — local PDF `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\362359657-Robo-forex-strategy.pdf`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11359_robo-adx-mom.md`

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
| v1 | 2026-06-18 | Initial build from card | DI-flip = single EVENT; ADX/Mom/PSAR/EMA = confirming STATES |
