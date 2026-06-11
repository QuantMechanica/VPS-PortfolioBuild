# QM5_11471_nekritin-peters-wammie-moolah-d1 — Strategy Spec

**EA ID:** QM5_11471
**Slug:** `nekritin-peters-wammie-moolah-d1`
**Source:** `7f773fbb-884e-54c9-a5d8-3f4087497622` (see `strategy-seeds/sources/7f773fbb-884e-54c9-a5d8-3f4087497622/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades D1 double touches of a recent support or resistance zone. A Wammie long is eligible when the latest closed D1 bar returns to a prior-touch support candidate inside the pattern window, closes as a strong bullish candle, and that prior touch was followed by a rally away from the zone. A Moolah short mirrors the rule at resistance, requiring a strong bearish second-touch candle after a prior-touch resistance candidate and sell-off. Entries are stop orders one pip beyond the second-touch candle, with stops beyond the two touch extremes and targets at the nearest recent swing level. If the first tradable tick after the signal close has already crossed the stop-entry level, the EA submits the equivalent market entry so the intended stop trigger is not missed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_zone_lookback_bars` | 50 | >= 1 | D1 bars used to define support and resistance zones. |
| `strategy_zone_exclude_recent` | 5 | >= 2 | Recent D1 bars excluded from zone definition. |
| `strategy_zone_buffer_pips` | 10.0 | > 0 | Maximum distance from zone level for a valid touch. |
| `strategy_min_rally_pips` | 30.0 | > 0 | Minimum move away from the zone between first and second touch. |
| `strategy_max_pattern_bars` | 20 | > gap | Maximum bars between first and second touch. |
| `strategy_min_touch_gap_bars` | 3 | >= 1 | Minimum separation between touches. |
| `strategy_catalyst_body_ratio` | 0.50 | > 0 | Minimum candle body as a fraction of full range on the second touch. |
| `strategy_entry_offset_pips` | 1.0 | > 0 | Stop-entry and protective-stop offset beyond the signal candle or touch extreme. |
| `strategy_pending_bars` | 3 | >= 1 | D1 bars before an unfilled stop order expires. |
| `strategy_max_sl_pips` | 120.0 | > 0 | Maximum allowed entry-to-stop distance. |
| `strategy_tp_scan_bars` | 60 | >= 3 | D1 bars scanned for nearest swing-high or swing-low target. |
| `strategy_spread_cap_pips` | 25.0 | > 0 | Maximum spread allowed before new entries are blocked. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — D1 FX major named by the approved card and present in the DWX matrix.
- `GBPUSD.DWX` — D1 FX major named by the approved card and present in the DWX matrix.
- `USDJPY.DWX` — D1 FX major named by the approved card and present in the DWX matrix.
- `AUDUSD.DWX` — D1 FX major named by the approved card and present in the DWX matrix.
- `USDCAD.DWX` — D1 FX major named by the approved card and present in the DWX matrix.

**Explicitly NOT for:**
- `SP500.DWX` — index exposure is outside the card's D1 FX basket.
- `XAUUSD.DWX` — metal exposure is outside the card's D1 FX basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `8` |
| Typical hold time | `days` |
| Expected drawdown profile | Fixed-risk reversal trades with one active position or pending order per symbol and capped 120-pip stop distance. |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `7f773fbb-884e-54c9-a5d8-3f4087497622`
**Source type:** `book`
**Pointer:** `Alex Nekritin and Walter Peters PhD, Naked Forex: High-Probability Techniques for Trading without Indicators, Chapter 7 (Wiley Trading, 2012)`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11471_nekritin-peters-wammie-moolah-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | 6dc790f1-32e1-4c36-9812-f44c4b03e54b |
| v2 | 2026-06-11 | Rework zone candidate scan for smoke trade generation | 8ed708bf-6bcc-46c2-a6b7-0d0c56b8c2fa |
| v3 | 2026-06-11 | Treat crossed stop-entry levels as triggered entries | 8ed708bf-6bcc-46c2-a6b7-0d0c56b8c2fa |
