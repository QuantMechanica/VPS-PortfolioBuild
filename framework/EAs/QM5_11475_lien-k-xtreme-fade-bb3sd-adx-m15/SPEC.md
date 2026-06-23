# QM5_11475_lien-k-xtreme-fade-bb3sd-adx-m15 - Strategy Spec

**EA ID:** QM5_11475
**Slug:** lien-k-xtreme-fade-bb3sd-adx-m15
**Source:** d0ac3635-33fb-5c22-916b-4b3c77f51bb9 (see `sources/lien-kathy-battle-tested-forex-bkforex`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades Kathy Lien's X-Treme Fade on M15 FX bars. It waits for the prior bar to close at a 3-standard-deviation Bollinger extreme, then requires the next closed bar to move back inside the matching 2-standard-deviation band while ADX(14) is below 25. The card labels the upper-band fade as BUY and the lower-band fade as SELL, so the EA follows that literal direction. Stops use the closer of a 5-bar structure stop and a 20-pip fixed stop, capped at 25 pips; take profit is 1R, with a post-1R stop trail toward the opposite 2SD band when that improves the stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 10-30 for P3 sweeps | Bollinger period used for both 3SD and 2SD bands. |
| `strategy_bb_dev_outer` | 3.0 | 2.5-3.5 for P3 sweeps | Outer extreme Bollinger deviation. |
| `strategy_bb_dev_inner` | 2.0 | fixed by card | Inner normal-zone Bollinger deviation. |
| `strategy_adx_period` | 14 | fixed by card | ADX period for range filtering. |
| `strategy_adx_max` | 25.0 | 20-30 for P3 sweeps | Entry allowed only when ADX is below this threshold. |
| `strategy_swing_lookback` | 5 | fixed by card | Bars used for the structural swing stop. |
| `strategy_sl_fixed_pips` | 20.0 | 15-20 for P3 sweeps | Fixed stop alternative before cap. |
| `strategy_sl_cap_pips` | 25.0 | fixed by card | Maximum stop distance. |
| `strategy_tp_rr` | 1.0 | 1.0-2.0 for P3 sweeps | Take-profit multiple of realized stop risk. |
| `strategy_spread_cap_pips` | 15.0 | fixed by card | Blocks only genuinely wider-than-cap spread. |
| `strategy_fast_adx_max` | 25.0 | literal ADX threshold | M1/M5 strong-against trend threshold. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid major FX pair.
- `GBPUSD.DWX` - card-listed liquid major FX pair.
- `USDJPY.DWX` - card-listed liquid major FX pair.
- `AUDUSD.DWX` - card-listed liquid major FX pair.
- `USDCAD.DWX` - card-listed liquid major FX pair.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - card R3 is M15 major FX only.
- FX pairs outside the card basket - not part of the approved R3 portable set for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | M1 and M5 ADX/DMI for the card's fast-trend-against filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Intraday, generally minutes to hours on M15 bars |
| Expected drawdown profile | Mean-reversion losses cluster during persistent band-walk trends |
| Regime preference | Mean-revert / low-trend ranging markets |
| Win rate target (qualitative) | Medium to high with capped losses |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d0ac3635-33fb-5c22-916b-4b3c77f51bb9
**Source type:** book / presentation PDF
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11475_lien-k-xtreme-fade-bb3sd-adx-m15.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11475_lien-k-xtreme-fade-bb3sd-adx-m15.md`

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
| v1 | 2026-06-23 | Initial build from card | b0d44c07-eea0-4fe7-a8fb-825e61c9e5c7 |
