# QM5_11476_lien-k-double-bb-trend-h1 - Strategy Spec

**EA ID:** QM5_11476
**Slug:** lien-k-double-bb-trend-h1
**Source:** d0ac3635-33fb-5c22-916b-4b3c77f51bb9 (see `sources/lien-kathy-battle-tested-forex-bkforex`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades Kathy Lien's Double Bollinger Band trend-zone system on H1. It builds two Bollinger Band envelopes with the same period and different deviations: an inner 1SD band and an outer 2SD band. A long entry fires when the latest closed bar moves into the upper zone between the inner and outer upper bands, with the middle band sloping up when enabled; a short entry fires symmetrically in the lower zone with the middle band sloping down. Positions exit when price closes back into the neutral channel inside the inner band.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_bb_period | 20 | 14-30 P3 sweep stated in card | Bollinger Band lookback period for both envelopes. |
| strategy_bb_dev_inner | 1.0 | 0.5-1.5 P3 sweep stated in card | Inner Bollinger deviation that defines the neutral-zone boundary. |
| strategy_bb_dev_outer | 2.0 | 2.0-3.0 P3 sweep stated in card | Outer Bollinger deviation that defines the extreme-zone boundary. |
| strategy_use_slope_filter | true | true/false | Requires middle-band slope to agree with trade direction. |
| strategy_slope_bars | 5 | 3-10 P3 sweep stated in card | Bar gap for middle-band slope comparison. |
| strategy_sl_fixed_pips | 40.0 | 40-60 P3 sweep stated in card | Fixed-pip fallback stop if the band stop is invalid. |
| strategy_sl_cap_pips | 60.0 | 1-60 | Skip entries whose dynamic opposite-inner-band stop exceeds this cap. |
| strategy_spread_cap_pips | 20.0 | 0-20 | Blocks entries only when modeled spread is genuinely wider than this. |
| strategy_no_friday_entry | true | true/false | Implements the card's no-Friday-entry filter. |
| strategy_direction_mode | 0 | -1/0/1 | Rescue-analysis switch: `0` trades both directions, `1` long-only, `-1` short-only. Default preserves the card logic. |
| strategy_min_exit_bars | 0 | 0-24 | Rescue-analysis switch: minimum bars before the neutral-channel exit may close a trade. Hard SL and Friday close remain framework-managed. Default preserves the card logic. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed H1 FX symbol with direct DWX availability.
- GBPUSD.DWX - Card-listed H1 FX symbol with direct DWX availability.
- USDJPY.DWX - Card-listed H1 FX symbol with direct DWX availability.
- AUDUSD.DWX - Card-listed H1 FX symbol with direct DWX availability.
- USDCAD.DWX - Card-listed H1 FX symbol with direct DWX availability.

**Explicitly NOT for:**
- SP500.DWX - Not part of the card's FX instrument list.
- NDX.DWX - Not part of the card's FX instrument list.
- XAUUSD.DWX - Not part of the card's FX instrument list.

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
| Expected trade frequency | Card implies regular H1 trend-zone entries; explicit frontmatter value not provided. |
| Typical hold time | Hold while price remains in the Double-BB trend zone; explicit frontmatter value not provided. |
| Expected drawdown profile | Trend-following zone system with capped per-trade stop distance. |
| Regime preference | Trend-following |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d0ac3635-33fb-5c22-916b-4b3c77f51bb9
**Source type:** book / presentation
**Pointer:** Kathy Lien, Battle Tested Forex Trading Strategies, Double Bollinger Bands; local PDF `142364071-Battle-Tested-Forex-Trading-Strategies.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11476_lien-k-double-bb-trend-h1.md`

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
| v1 | 2026-06-23 | Initial build from card | 79b567d9-e8d1-44d2-8131-392e4cec5550 |
| v2 | 2026-06-28 | Q05 near-miss rescue variants | Added neutral-default direction and minimum-hold inputs after USDJPY deal analysis showed long-side and longer-hold edge concentration. |
