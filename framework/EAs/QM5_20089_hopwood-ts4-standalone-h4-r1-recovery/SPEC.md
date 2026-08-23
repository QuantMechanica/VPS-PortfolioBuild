# QM5_20089_hopwood-ts4-standalone-h4-r1-recovery — Strategy Spec

**EA ID:** QM5_20089
**Slug:** `hopwood-ts4-standalone-h4-r1-recovery`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (Steve Hopwood Forex Factory TS-series archive)
**Author of this spec:** Codex
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

On each new H4 bar, the EA buys when +DI(14) exceeds -DI(14), the MACD(12,26,9)
histogram is positive, the close breaks above the prior 20-bar high, and the D1
EMA(200) slope is positive. It sells on the exact mirror. Entries also require a
minimum 0.4-ATR H4 bar, an acceptable ATR-relative spread, and no same-direction
entry within six H4 bars. The initial stop is 1.5 ATR(14). At +2 ATR the EA closes
half, moves the remainder to break-even plus spread, and then trails by PSAR. Any
component of the held-direction stack breaking, or 24 elapsed H4 bars, closes the
remaining position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_dmi_period` | 14 | 10-20 | DMI directional-consensus period. |
| `strategy_macd_fast` | 12 | 8-16 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | 21-34 | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 6-12 | MACD signal period. |
| `strategy_channel_period` | 20 | 15-30 | Prior-bar HHV/LLV breakout window. |
| `strategy_atr_period` | 14 | 10-30 | ATR period for entry filters and protection. |
| `strategy_atr_sl_mult` | 1.5 | 1.0-2.5 | Initial stop distance in ATR units. |
| `strategy_atr_tp_mult` | 2.0 | 1.5-3.0 | T1 partial-close distance in ATR units. |
| `strategy_psar_step` | 0.02 | 0.01-0.03 | PSAR trail acceleration step. |
| `strategy_psar_max` | 0.2 | 0.1-0.3 | PSAR maximum acceleration. |
| `strategy_cooldown_bars` | 6 | 3-15 | Same-direction H4 re-entry cooldown. |
| `strategy_timestop_bars` | 24 | 12-36 | Maximum holding period in H4 bars. |
| `strategy_range_gate_mult` | 0.4 | 0.3-0.6 | Minimum closed-bar range in ATR units. |
| `strategy_spread_gate_mult` | 0.35 | 0.2-0.5 | Maximum spread in ATR units. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX` — liquid FX-major ports.
- `NDX.DWX`, `WS30.DWX` — liquid US index-CFD ports.
- `XAUUSD.DWX`, `XTIUSD.DWX` — metals and energy diversification ports.

**Explicitly NOT for:**
- Symbols outside the governed DWX matrix or without complete H4/D1 history.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | D1 EMA(200) slope regime gate |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with an H4 chart guard |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 20 |
| Typical hold time | one to 24 H4 bars |
| Expected drawdown profile | card estimate around 15%; ATR stop, partial T1, time stop, and central governors constrain exposure |
| Regime preference | sustained directional breakout with D1 trend agreement |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** named-author forum system archive
**Pointer:** Steve Hopwood Forex Factory Trading-Systems TS-series threads, as catalogued by the approved card.
**R1-R4 verdict (Q00):** R1 lineage recorded and R2-R4 PASS per
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_20089_hopwood-ts4-standalone-h4-r1-recovery.md`.

The card records the governed identity recovery from conflicting draft EA ID 1603 to
the active EA ID 20089; registry, folder, and magic rows now agree on the recovered identity.

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
| v1 | 2026-08-23 | Completed recovered build package and framework alignment | task d00ea063-eb22-41c0-85f3-f793f11a3978 |
