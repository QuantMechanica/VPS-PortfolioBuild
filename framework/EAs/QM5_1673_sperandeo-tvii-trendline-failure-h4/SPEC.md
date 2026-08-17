# QM5_1673_sperandeo-tvii-trendline-failure-h4 — Strategy Spec

**EA ID:** QM5_1673
**Slug:** `sperandeo-tvii-trendline-failure-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Codex
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

On each newly closed H4 bar, the EA locates the most recent confirmed pair of
higher low pivots and lower high pivots, using five completed bars on each side
of a pivot, and projects the resulting two-point trendline. A reversal becomes
eligible when price closes through that line by more than 0.5 ATR(14) and none
of the following four completed bars recovers the line. The EA sells a failed
rising trendline only below the closed D1 SMA(200), and buys a failed falling
trendline only above it.

The initial stop is the pre-violation price extreme plus a 0.5 ATR buffer, capped
at 3 ATR from entry. The profit target is a 50% retracement of the prior dominant
trend range. The position also exits after 30 H4 bars or on an opposite signal;
at +1.5 ATR the stop moves to break-even plus spread, and at half of the target
distance the EA closes half of the position once. Simultaneous long and short
signals fail closed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_pivot_strength` | 5 | 3–7 | Completed bars required on each side of a structural pivot. |
| `strategy_atr_period` | 14 | 2–100 | H4 ATR lookback used for tolerance, stops, and management. |
| `strategy_violation_atr_mult` | 0.5 | 0.25–1.0 | Minimum trendline penetration, in ATR units. |
| `strategy_cancellation_bars` | 4 | 3–6 | Completed bars that must fail to recover the violated line. |
| `strategy_trendline_max_age` | 144 | 20–300 | Maximum age of a construction pivot, in H4 bars. |
| `strategy_regime_sma_period` | 200 | 20–400 | Closed D1 SMA regime lookback. |
| `strategy_target_retrace` | 0.5 | 0.382–0.618 | Fraction of the prior trend range used for the target. |
| `strategy_stop_buffer_atr` | 0.5 | 0–2.0 | ATR buffer beyond the pre-violation extreme. |
| `strategy_stop_atr_cap` | 3.0 | 2.0–4.0 | Maximum entry-to-stop distance, in ATR units. |
| `strategy_time_stop_bars` | 30 | 20–60 | Maximum holding time in H4 bars. |
| `strategy_be_trigger_atr` | 1.5 | 0.5–4.0 | Favorable ATR move that activates break-even. |
| `strategy_partial_target_frac` | 0.5 | 0.25–0.75 | Fraction of target distance that activates the partial exit. |
| `strategy_partial_close_frac` | 0.5 | 0.1–0.9 | Fraction of current volume closed at the partial exit. |
| `strategy_cooldown_bars` | 18 | 0–100 | Same-direction re-entry delay in H4 bars. |
| `strategy_spread_atr_mult` | 0.3 | 0.05–1.0 | Maximum entry spread as a fraction of H4 ATR. |

Framework risk, news, Friday-close, RNG, and stress inputs are documented in
`framework/V5_FRAMEWORK_DESIGN.md` and are not strategy parameters.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`,
  `USDCAD.DWX`, and `NZDUSD.DWX` — liquid FX majors suitable for the card's
  symbol-agnostic H4 OHLC structure; NZDUSD is the diversity-first Q02 lead.
- `GDAXI.DWX`, `NDX.DWX`, `SP500.DWX`, `UK100.DWX`, and `WS30.DWX` — liquid
  index CFDs included by the approved card's portable H4 universe.
- `XAUUSD.DWX` — liquid precious-metal CFD included by the approved card.

Each symbol has a distinct active magic-registry slot. Passing one symbol does
not imply validity on another; every instrument requires its own pipeline row.

**Explicitly NOT for:**

- Symbols outside `framework/registry/dwx_symbol_matrix.csv` — the farm cannot
  provide governed Darwinex test history or routing for them.
- Crypto, rates, and energy contracts — this EA has no active magic-registry
  slot for those instruments in this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | Closed D1 close and SMA(200) regime state |
| Bar gating | One `QM_IsNewBar()` call per tick; structural scans occur only on the latched new-H4-bar path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Low frequency; approximately 2–12, to be measured at Q02 rather than assumed |
| Typical hold time | Several H4 bars to five days; hard stop at 30 H4 bars |
| Expected drawdown profile | Episodic losses around false structural breaks; no averaging, grid, or martingale recovery |
| Regime preference | Confirmed trendline-failure reversal aligned with the D1 price/SMA regime |
| Win rate target (qualitative) | Medium; payoff and robustness matter more than hit rate |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`

**Source type:** Book and public forum lineage

**Pointer:** Victor Sperandeo, *Trader Vic II: Principles of Professional
Speculation*, Wiley, 1994, ISBN 0-471-04953-8, chapter 7, pp. 159–188; source
node `sources/forexfactory-trading-systems`

**R1–R4 verdict (Q00):** all PASS per
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_1673_sperandeo-tvii-trendline-failure-h4.md`

The approved Strategy Card is preserved verbatim in `docs/strategy_card.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). This build and its setfiles are research and
backtest artifacts only; they grant no live or deployment authorization.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-17 | Initial build from approved card | Task `977c8c04-f57b-40f7-9b3b-3d89d5bf237e` |
