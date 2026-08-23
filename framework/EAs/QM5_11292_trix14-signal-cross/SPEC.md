# QM5_11292_trix14-signal-cross — Strategy Spec

**EA ID:** QM5_11292
**Slug:** `trix14-signal-cross`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (archived ForexStrategiesResources TRIX article)
**Author of this spec:** Codex
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

On each new H1 bar, the EA computes TRIX as the percentage rate of change of a
triple-smoothed EMA of closed prices. The primary rule buys when TRIX(14) crosses
above its EMA(9) signal line and sells when it crosses below; the authorized P3
variant can instead use a zero-line cross. An opposite cross closes the existing
position before a reverse entry. Each entry receives a 1.5 ATR(14) stop, a 2.5
ATR(14) safety take-profit, and moves its stop to break-even after gaining one
initial risk unit. New entries are rejected above the 20-pip spread cap.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_trix_period` | 14 | 9-21 | Period used for all three EMA smoothing passes. |
| `strategy_signal_period` | 9 | 5-13 | EMA period of the TRIX signal line. |
| `strategy_signal_method` | 1 | 1-2 | 1 uses the signal-line cross; 2 uses the authorized zero-line variant. |
| `strategy_warmup_bars` | 240 | 180-500 | Closed-price history used to seed the recursive EMA calculations. |
| `strategy_atr_period` | 14 | 10-30 | ATR period for the protective stop and safety target. |
| `strategy_atr_sl_mult` | 1.5 | 1.0-2.5 | Initial stop distance in ATR units. |
| `strategy_atr_tp_mult` | 2.5 | 1.5-4.0 | Safety take-profit distance in ATR units. |
| `strategy_max_spread_pips` | 20.0 | 2.0-20.0 | Maximum spread permitted for a new entry. |
| `strategy_use_ema200_filter` | false | false/true | Enables the card-authorized P3 EMA(200) trend context. |
| `strategy_trend_ema_period` | 200 | 100-300 | EMA period used when the optional trend filter is enabled. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair named by the approved card.
- `GBPUSD.DWX` — liquid major FX pair named by the approved card.
- `USDJPY.DWX` — liquid major FX pair named by the approved card.
- `AUDUSD.DWX` — liquid major FX pair named by the approved card.

**Explicitly NOT for:**
- Non-FX CFDs — the card's 20-pip spread convention and evidence are scoped to major FX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 30 |
| Typical hold time | hours to several days, until reverse cross or protective exit |
| Expected drawdown profile | card estimate around 18%; controlled per trade by the ATR stop and central governors |
| Regime preference | persistent trend with reduced oscillator noise |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** archived article / PDF
**Pointer:** ForexStrategiesResources "Trix Strategy Trading System" archive referenced by the approved card.
**R1-R4 verdict (Q00):** R1 lineage recorded and R2-R4 PASS per
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_11292_trix14-signal-cross.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`; every backtest set keeps
`RISK_FIXED > 0` and `RISK_PERCENT = 0`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-23 | Completed implementation from approved card | task 56e67144-da6b-48b8-89ae-ba7048da97a9 |
