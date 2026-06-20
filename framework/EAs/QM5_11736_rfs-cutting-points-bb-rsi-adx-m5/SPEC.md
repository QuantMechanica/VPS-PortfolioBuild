# QM5_11736_rfs-cutting-points-bb-rsi-adx-m5 - Strategy Spec

**EA ID:** QM5_11736
**Slug:** rfs-cutting-points-bb-rsi-adx-m5
**Source:** b5a932a2-40b6-5628-840b-d5069ac35c4a
**Author of this spec:** Codex
**Last revised:** 2026-06-21

---

## 1. Strategy Logic

This EA trades a Bollinger Band mean-reversion scalp on M5. A long setup requires the prior closed bar to close at or below the lower BB(20,2), RSI(7) below 30, and ADX(14) below 30; entry fires on the next closed bar when price returns above the lower band. A short setup mirrors the rule at the upper band with RSI above 70 and a return close below the upper band. Stops sit 3 pips beyond the active outer band and the take-profit is managed to the BB middle line.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 20 | 2+ | Bollinger Band moving-average period. |
| `strategy_bb_deviation` | 2.0 | >0 | Bollinger Band standard-deviation multiplier. |
| `strategy_rsi_period` | 7 | 2+ | RSI period for overbought and oversold confirmation. |
| `strategy_rsi_oversold` | 30.0 | 0-100 | Long setup RSI threshold. |
| `strategy_rsi_overbought` | 70.0 | 0-100 | Short setup RSI threshold. |
| `strategy_adx_period` | 14 | 2+ | ADX period for range filter. |
| `strategy_adx_max` | 30.0 | 0+ | Maximum ADX allowed for entries. |
| `strategy_sl_pips` | 3 | 1+ | Stop buffer beyond the active outer Bollinger Band, in pips. |
| `strategy_trade_start_hour` | 0 | 0-23 | Optional broker-hour session start; default leaves trading unrestricted. |
| `strategy_trade_end_hour` | 24 | 1-24 | Optional broker-hour session end; default leaves trading unrestricted. |
| `strategy_max_spread_pips` | 0 | 0+ | Optional spread cap in pips; zero disables the cap. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with DWX M5 data.
- `GBPUSD.DWX` - card-listed major FX pair with DWX M5 data.
- `AUDUSD.DWX` - card-listed major FX pair with DWX M5 data.
- `USDCAD.DWX` - card-listed major FX pair with DWX M5 data.

**Explicitly NOT for:**
- Non-FX index or commodity symbols - the approved card targets only the four listed FX pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Expected trade frequency | Not specified in card frontmatter; body describes an M5 scalp cadence. |
| Typical hold time | Not specified in card frontmatter; expected to be intraday because exits target the BB middle line on M5. |
| Expected drawdown profile | Not specified in card frontmatter; strict 3-pip band-buffer stop per trade. |
| Regime preference | Mean-reversion in sideways or calm markets; ADX below 30 required. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b5a932a2-40b6-5628-840b-d5069ac35c4a
**Source type:** anonymous online strategy compilation
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11736_rfs-cutting-points-bb-rsi-adx-m5.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11736_rfs-cutting-points-bb-rsi-adx-m5.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-21 | Initial build from card | 5588e487-9a3e-4a4c-93f6-faa35fd5dc16 |
