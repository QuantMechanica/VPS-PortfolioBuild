# QM5_11477_williams-l-fakeout-day-d1 — Strategy Spec

**EA ID:** QM5_11477
**Slug:** `williams-l-fakeout-day-d1`
**Source:** `b943674a-985e-5634-8420-47a9412c3ab5`
**Author of this spec:** Codex
**Last revised:** 2026-08-08

---

## 1. Strategy Logic

On each new D1 bar, the EA checks whether the previous day made both a higher high and a higher low but closed below the day before; that pattern places a buy stop one pip above the signal day's high. The mirror pattern—lower high, lower low, and a higher close—places a sell stop one pip below the signal day's low. Each pending order expires after one D1 bar, the stop sits one pip beyond the opposite signal-day extreme, the target is 1.5 times the signal-day range beyond its entry-side extreme, and an open trade is closed after five completed D1 bars when it is not profitable.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_buffer_pips` | 1 | fixed baseline | Pip offset beyond the signal-day high or low for the pending stop entry. |
| `strategy_sl_buffer_pips` | 1 | fixed baseline | Pip offset beyond the opposite signal-day extreme for the protective stop. |
| `strategy_max_signal_range_pips` | 80 | fixed P2 cap | Skip a signal whose D1 high-low range exceeds this cap. |
| `strategy_tp_range_mult` | 1.5 | 1.0–2.0 | Measured-move target as a multiple of the signal-day range. |
| `strategy_pending_expiry_bars` | 1 | fixed baseline | Number of D1 bars before an unfilled pending order expires. |
| `strategy_time_stop_bars` | 5 | 1, 3, or 5 | Completed D1 bars before the non-profitable time-stop test. |
| `strategy_require_close_third` | false | false / true | Optionally require the long close in the bottom third or short close in the top third. |
| `strategy_no_friday_entry` | true | true | Prevent new Friday entries as required by the card. |
| `strategy_spread_cap_pips` | 25 | fixed baseline | Block entry only when the modeled spread is genuinely wider than 25 pips. |

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card-listed D1 DWX FX instrument with canonical matrix coverage.
- `GBPUSD.DWX` — card-listed D1 DWX FX instrument with canonical matrix coverage.
- `USDJPY.DWX` — card-listed D1 DWX FX instrument with canonical matrix coverage.
- `AUDUSD.DWX` — card-listed D1 DWX FX instrument with canonical matrix coverage.
- `USDCAD.DWX` — card-listed D1 DWX FX instrument with canonical matrix coverage.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` — the build contract forbids phantom or non-canonical backtest symbols.
- Intraday timeframes — the source rule is defined from completed daily bars.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Typical hold time | Pending for at most one D1 bar; an unprofitable position exits after five completed D1 bars. |
| Expected drawdown profile | Not specified in the approved card. |
| Regime preference | Daily false-breakout reversal after a directional-looking higher-range or lower-range day. |
| Win rate target (qualitative) | Not specified in the approved card. |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b943674a-985e-5634-8420-47a9412c3ab5`
**Source type:** book/workshop PDF
**Pointer:** Larry Williams, *Inner Circle Workshop Trading Method* (~2000), local PDF `Inner Circle Workshop Trading Method. (Larry Williams) (Z-Library).pdf`.
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11477_williams-l-fakeout-day-d1.md`.

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
| v1 | 2026-08-08 | Initial build from card | 9b0fd485-cacc-421e-b3ae-cac816327bcf |
