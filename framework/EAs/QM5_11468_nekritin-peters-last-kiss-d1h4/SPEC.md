# QM5_11468_nekritin-peters-last-kiss-d1h4 - Strategy Spec

**EA ID:** QM5_11468
**Slug:** `nekritin-peters-last-kiss-d1h4`
**Source:** `7f773fbb-884e-54c9-a5d8-3f4087497622`
**Author of this spec:** Codex
**Last revised:** 2026-08-13

---

## 1. Strategy Logic

On each completed D1 bar, the EA finds a five-to-thirty-bar consolidation box
whose width is inside fixed pip bounds, followed by the first close outside the
box. It waits for the first subsequent retouch of the broken edge and requires
that retouch bar to reject and close back in the breakout direction. A one-bar
buy-stop is placed one pip above a bullish rejection high, or a one-bar
sell-stop one pip below a bearish rejection low. The stop is the box midpoint;
the target is a prior structural extreme beyond entry or, when none exists,
1.5 box heights. A completed close back through the broken edge or twenty D1
bars in the trade closes the position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_box_bars` | 10 | 5-30 | Completed D1 bars used to define the consolidation box. |
| `strategy_box_min_pips` | 30 | 1-120 | Minimum accepted box width. |
| `strategy_box_max_pips` | 120 | 30+ | Maximum accepted box width. |
| `strategy_zone_buffer_pips` | 10 | 0-30 | Maximum distance from the broken edge that counts as a retouch. |
| `strategy_retouch_window` | 10 | 1-10 | Maximum completed bars between breakout and first retouch. |
| `strategy_entry_offset_pips` | 1 | 1-5 | Stop-entry offset beyond the rejection bar. |
| `strategy_pending_expiry_bars` | 1 | fixed at 1 | Pending stop validity in D1 bars. |
| `strategy_sl_cap_pips` | 120 | 1+ | Maximum entry-to-box-midpoint stop distance. |
| `strategy_tp_swing_lookback` | 30 | 3+ | Older D1 bars searched for the structural target. |
| `strategy_tp_box_mult` | 1.5 | positive | Fallback target distance in box heights. |
| `strategy_time_stop_bars` | 20 | 1+ | Maximum completed D1 bars held. |
| `strategy_spread_cap_pips` | 25 | positive | Maximum genuine spread for a new entry. |

Framework inputs such as `RISK_FIXED`, `RISK_PERCENT`, news handling, Friday
close, and deterministic stress are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` - liquid euro/dollar D1 structure and the card's first FX host.
- `GBPUSD.DWX` - liquid sterling/dollar D1 structure.
- `USDJPY.DWX` - liquid yen major with different currency-factor exposure.
- `AUDUSD.DWX` - liquid commodity-currency major.
- `USDCAD.DWX` - liquid North American commodity-currency major.

**Explicitly NOT for:**

- Index, metal, energy, crypto, and synthetic pair symbols - the approved card
  defines an FX-major baseline only; broadening it would be a strategy change.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)`; `_Period` is required to be D1 |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 12 |
| Typical hold time | 1-20 D1 bars |
| Expected drawdown profile | Sparse fixed-risk losses around failed breakout retouches; one position per magic. |
| Regime preference | Consolidation followed by a sustained breakout and orderly edge retouch. |
| Win rate target (qualitative) | Medium; payoff is asymmetric when prior structure is distant. |

---

## 6. Source Citation

**Source ID:** `7f773fbb-884e-54c9-a5d8-3f4087497622`
**Source type:** book
**Pointer:** Alex Nekritin and Walter Peters, *Naked Forex: High-Probability
Techniques for Trading without Indicators*, chapter 5, Wiley Trading, 2012.
**R1-R4 verdict (Q00):** R1 lineage recorded and R2-R4 PASS per
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_11468_nekritin-peters-last-kiss-d1h4.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-13 | Q01 rebuild from the approved card | `f0eebcde-ab98-4c70-8795-1ab5cbca68e9` |
