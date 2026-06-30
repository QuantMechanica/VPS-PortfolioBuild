# QM5_12823_lien-double-bb-trend-pyramid-h1 - Strategy Spec

**EA ID:** QM5_12823
**Slug:** lien-double-bb-trend-pyramid-h1
**Source:** AI-claude-pyramid-poc-11476-20260630
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

This EA trades the USDJPY.DWX H1 Double Bollinger Band trend-zone rule from QM5_11476, long-only. A new host position opens when the latest closed H1 bar transitions into the strong-buy zone between the 1 standard deviation upper band and the 2 standard deviation upper band, while the Bollinger middle band is rising. While a long position is open, the EA may add one new unit on a later closed bar if the strong-buy zone still holds and current price is above the volume-weighted average entry. All units exit when the closed H1 bar falls back below the inner upper band, or through the common raised stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_bb_period | 20 | 5-100 | Bollinger Band period for inner and outer bands. |
| strategy_bb_dev_inner | 1.0 | 0.5-3.0 | Inner band deviation defining the strong-buy zone edge. |
| strategy_bb_dev_outer | 2.0 | 1.0-4.0 | Outer band deviation defining the strong-buy zone cap. |
| strategy_slope_bars | 5 | 1-20 | Middle-band slope comparison lookback. |
| strategy_sl_fixed_pips | 40.0 | 5-200 | Fixed stop fallback when the band stop is invalid. |
| strategy_sl_cap_pips | 60.0 | 5-200 | Maximum allowed dynamic band-stop distance. |
| strategy_spread_cap_pips | 20.0 | 1-100 | Blocks only genuinely wide positive spreads; zero DWX spread passes. |
| strategy_no_friday_entry | true | true/false | Blocks new host or add entries on Friday while exits remain active. |
| strategy_max_adds | 3 | 0-4 | Maximum add units after the host position. |
| strategy_add_size_mode | 0 | 0-1 | 0 equal add units; 1 decreasing add schedule. |
| strategy_aggregate_risk_cap_pct | 1.0 | 0.1-2.0 | Percent-equity aggregate risk cap when not in fixed-risk backtest mode. |
| strategy_trail_method | 0 | 0-2 | Common stop method: 0 band, 1 structure, 2 ATR. |
| strategy_trail_structure_bars | 10 | 2-100 | Lookback for structure stop when selected. |
| strategy_trail_atr_period | 20 | 2-100 | ATR period for ATR stop when selected. |
| strategy_trail_atr_mult | 2.0 | 0.5-10.0 | ATR multiplier for ATR stop when selected. |

---

## 3. Symbol Universe

**Designed for:**
- USDJPY.DWX - the card's R3 PASS survivor symbol from QM5_11476 and the only symbol named for the A/B pyramiding proof of concept.

**Explicitly NOT for:**
- Other FX pairs - not part of this card's R3 PASS universe.
- Indices, metals, and energy symbols - not part of the Kathy Lien USDJPY Double-BB survivor baseline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via the framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 card-stated host entries before pyramid adds |
| Typical hold time | Not stated in frontmatter; H1 trend-zone holds are expected to last hours to days until the band exit. |
| Expected drawdown profile | 8 percent card-stated expected DD, with aggregate open risk capped by the common stop. |
| Regime preference | Trend-following, positive-skew trend continuation. |
| Win rate target (qualitative) | Medium to low, with payoff driven by open-ended trend winners. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** AI-claude-pyramid-poc-11476-20260630
**Source type:** AI overlay on book-derived Kathy Lien Double-BB baseline
**Pointer:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_12823_lien-double-bb-trend-pyramid-h1.md
**R1-R4 verdict (Q00):** all PASS / see artifacts/cards_approved/QM5_12823_lien-double-bb-trend-pyramid-h1.md

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-30 | Initial build from card | 6f4d26a7-1330-4914-8a8d-a652f6e8cb00 |
