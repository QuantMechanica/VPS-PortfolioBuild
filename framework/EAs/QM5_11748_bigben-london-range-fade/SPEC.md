# QM5_11748_bigben-london-range-fade - Strategy Spec

**EA ID:** QM5_11748
**Slug:** bigben-london-range-fade
**Source:** 54fedbdc-d2bd-5000-acdd-e4dd3e633f3e (see `strategy-seeds/sources/54fedbdc-d2bd-5000-acdd-e4dd3e633f3e/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA measures the Asian session range from 00:00 through 07:00 UTC on H1 bars. If the 07:00 UTC pre-London bar closes above that range, the EA opens a short fade when the completed 08:00 UTC bar closes back below the Asia high. If the 07:00 UTC bar closes below the range, the EA opens a long fade when the completed 08:00 UTC bar closes back above the Asia low. The stop is the pre-London breakout close extreme, the target is one full Asia range projected past the opposite side, and same-day open trades are closed by the strategy time stop from 09:00 UTC onward.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_asia_start_hour_utc` | 0 | 0-23 | First UTC hour included in the Asia range. |
| `strategy_asia_end_hour_utc` | 7 | 1-24 | First UTC hour excluded after the Asia range. |
| `strategy_breakout_start_hour_utc` | 7 | 0-23 | First UTC hour included in the pre-London breakout window. |
| `strategy_breakout_end_hour_utc` | 8 | 1-24 | First UTC hour excluded after the pre-London breakout window. |
| `strategy_fade_hour_utc` | 8 | 0-23 | UTC hour of the completed fade candle to evaluate. |
| `strategy_time_stop_hour_utc` | 9 | 0-23 | UTC hour from which same-day positions are closed by the time stop. |
| `strategy_history_bars_h1` | 16 | 10-48 | Number of H1 bars copied for the bounded session-window calculation. |
| `strategy_use_body_range` | false | true/false | If true, use candle bodies for the Asia range; default follows the factory simplified high-low interpretation. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - primary Big Ben pair from the source's London-open GBP focus.
- `GBPJPY.DWX` - GBP cross with London-session activity and card-listed portability.
- `EURUSD.DWX` - liquid European session major listed in the approved card.
- `USDJPY.DWX` - liquid major listed in the approved card.
- `AUDUSD.DWX` - liquid major listed in the approved card.

**Explicitly NOT for:**
- `SP500.DWX` - index exposure is outside the card's FX session-fade universe.
- `XAUUSD.DWX` - metals are not part of the source or card symbol list.
- `BTCUSD.DWX` - crypto is not part of the source or card symbol list.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | about 1 hour to intraday SL/TP completion |
| Expected drawdown profile | False-breakout mean-reversion losses cluster on trend continuation days. |
| Regime preference | mean-revert / false-breakout fade around London open |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 54fedbdc-d2bd-5000-acdd-e4dd3e633f3e
**Source type:** anonymous web article / local PDF archive
**Pointer:** Anonymous, "Big Ben Breakout Strategy", tradingstrategyguides.com, local Source PDF `450251566-Big-Ben-Breakout-Strategy-pdf.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11748_bigben-london-range-fade.md`

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
| v1 | 2026-06-11 | Initial build from card | f579bdb3-287e-4c49-8116-41049876807b |
