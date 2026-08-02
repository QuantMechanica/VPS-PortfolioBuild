# QM5_20188_ff-rb-tue-off - Strategy Spec

**EA ID:** QM5_20188
**Slug:** `ff-rb-tue-off`
**Parent:** `QM5_9936_ff-range-breakout-gmt3-h1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` plus the frozen Tuesday diagnosis
**Author of this spec:** Codex
**Last revised:** 2026-07-31

---

## 1. Strategy Logic

The EA is a separate, non-inheriting variant of QM5_9936. It builds the completed 01:00-06:00 GMT+3 H1 range for the current trading day. On Tuesday GMT+3 it consumes the day without placing orders. On all other weekdays, at 06:00 GMT+3 it places a buy stop at the range high and a sell stop at the range low, with the initial stop on the opposite side of the range and no fixed take profit. It skips the day when the range height is below 0.4 x ATR(14,H1) or above 2.5 x ATR(14,H1). Open trades close at 20:00 GMT+3, on an opposite range-side touch, or trail to the prior two completed H1 lows/highs after price has moved at least +1R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_range_start_hour_gmt3` | 1 | 0-23 | First GMT+3 hour included in the range. |
| `strategy_range_end_hour_gmt3` | 6 | 1-24 | First GMT+3 hour after the range and the order placement hour. |
| `strategy_order_cancel_hour_gmt3` | 13 | 0-23 | GMT+3 hour at which untriggered stop orders are removed. |
| `strategy_session_close_hour_gmt3` | 20 | 0-23 | GMT+3 hour at which open positions are closed. |
| `strategy_atr_period` | 14 | >=1 | ATR period used for range-height filters. |
| `strategy_min_range_atr_mult` | 0.4 | >0 | Minimum range height as a multiple of ATR(14,H1). |
| `strategy_max_range_atr_mult` | 2.5 | >0 | Maximum range height and hard SL cap as a multiple of ATR(14,H1). |
| `strategy_trail_trigger_r` | 1.0 | >=0 | Profit in R before the prior-two-bar trailing stop starts. |
| `strategy_range_scan_bars` | 36 | >=6 | Closed H1 bars scanned to reconstruct the current GMT+3 session range. |
| `strategy_skip_tuesday` | true | true only | Frozen pre-entry Tuesday guard selected before the variant's OOS run. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - card R3 lists USDJPY and the symbol is present in the DWX matrix.
- `GBPUSD.DWX` - card R3 lists GBPUSD and the symbol is present in the DWX matrix.
- `NDX.DWX` - card R3 maps NAS100 exposure to the DWX Nasdaq 100 symbol.

**Explicitly NOT for:**
- Symbols outside the card's R3 basket - not registered for this EA in `magic_numbers.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately `112` after removing Tuesday entries. |
| Typical hold time | Same-day intraday hold, from 06:00 GMT+3 entry window until no later than 20:00 GMT+3. |
| Expected drawdown profile | Fixed-risk breakout losses bounded by the completed 01:00-06:00 GMT+3 range. |
| Regime preference | Breakout / volatility-expansion days after a valid overnight range. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** `https://www.forexfactory.com/thread/1299658-range-breakout-system`
**R1-R4 verdict (G0):** all PASS per `D:/QM/strategy_farm/artifacts/cards_approved/QM5_20188_ff-rb-tue-off.md`. The Tuesday enhancement is predeclared in `docs/ops/evidence/2026-07-27_9936_drawdown_diagnosis.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live / T_Live | not authorized | This card creates no live setfile or deploy permission. |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## 8. Non-gate T5 Validation (2026-07-31)

The frozen primary-symbol comparison used T5, Model 4, H1, fixed $1,000 risk,
and identical current-framework parent/variant builds. On the untouched
2022-2025 OOS window, FUND_SCORE improved from `0.393515` to `0.557570`,
profit factor from `1.28` to `1.48`, net profit from `$71,402.49` to
`$96,008.24`, and MT5 drawdown from `19.61%` to `14.25%`.

Across 2017-2025, all 1,039 retained USDJPY trades were economically identical
to the parent, 216 parent trades were removed, all 216 entries were Tuesday
GMT+3, and no trade was added or shifted. Full-history FUND_SCORE improved
from `0.341561` to `0.428942`.

The cross-symbol falsification did not qualify GBPUSD: the variant improved
the parent but remained negative (`PF 0.97`, net `-$11,534.76`). NDX was not
measured because T5 returned `NO_HISTORY` on all three attempts. These outcomes
must not be tuned away or represented as passing gates. Full evidence is in
`docs/ops/evidence/2026-07-31_20188_best_ea_t5.md`.

This is experiment evidence, not an independent factory-gate verdict,
portfolio admission, deploy approval, or live authorization.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-31 | Isolated Tuesday-off variant of QM5_9936 | OWNER best-EA mission; no inherited gate evidence |
| v2 | 2026-07-31 | Record frozen T5 comparison | USDJPY wins; GBPUSD fails; NDX unmeasured; live remains unauthorized |
