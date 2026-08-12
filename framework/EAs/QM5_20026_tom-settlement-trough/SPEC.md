# QM5_20026_tom-settlement-trough — Strategy Spec

**EA ID:** QM5_20026
**Slug:** `tom-settlement-trough`
**Source:** `ETULA-DASHFORCASH-TOM-2020` (see `strategy-seeds/sources/ETULA-DASHFORCASH-TOM-2020/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-21

---

## 1. Strategy Logic

Institutional investors face predictable, calendar-locked cash needs around
month-end (redemptions, margin, reporting, reinvestment). To have cash
settled by month-end they must sell securities a fixed number of days
earlier — the exchange's regulatory settlement lag. This concentrated,
price-inelastic selling depresses equity index prices into a trough a few
trading days before month-end, after which prices recover as the cash is
redeployed at and after the turn of the month.

The EA goes LONG at the close of the settlement-derived trough bar,
`T-(L+1)` trading days before the last trading day of the calendar month,
where `L` is the exchange's regulatory settlement lag in effect on that date
(a fixed, era-aware table — never a hardcoded T-4). It exits at the close of
the 3rd trading day of the new month. A flat-filter suppresses long
initiation on every other day in the pre-turn decline band T-8..T-4 (the
paper's short leg has no out-of-sample confirmation and ships only as a
"do not buy the falling knife" guard, never an unconditional short). A
frozen `2.75 * ATR(20, D1)` stop protects the position; there is no
take-profit — the edge is the calendar window, not a price level.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_trough_offset_current_de` | 3 | fixed (era-locked) | Current-era GDAXI trough offset T-3 (EU CSDR T+2, from 2014-10-06). |
| `strategy_trough_offset_current_us` | 2 | fixed (era-locked) | Current-era US-index trough offset T-2 (SEC T+1, from 2024-05-28). |
| `strategy_flat_band_from` | 8 | fixed | Start of the pre-turn decline flat-filter band (T-8). |
| `strategy_flat_band_to` | 4 | fixed | End of the pre-turn decline flat-filter band (T-4). |
| `strategy_exit_newmonth_tradingday` | 3 | fixed | Exit at close of the N-th trading day of the new month (T+3 new). |
| `strategy_atr_period` | 20 | fixed | D1 ATR period for the frozen stop. |
| `strategy_atr_sl_mult` | 2.75 | fixed | ATR multiple for the frozen protective stop. |
| `strategy_max_spread_points` | 2500 | fixed | Locked maximum spread guard (points). |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.
>
> All values above are published small integers derived from settlement
> regulatory dates, not fitted scalars (card §8). The legacy pre-era offsets
> (T-4 on both venues under the T+3 regime, and T-3 for the US T+2 era
> 2017-09-05..2024-05-27) are hardcoded era-table constants inside the EA,
> not swept inputs, per card §4/§8's era table.

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` (slot 0) — DAX/DE40, EU CSDR settlement era (T+2 from 2014-10-06).
- `NDX.DWX` (slot 1) — Nasdaq 100, US SEC settlement era table.
- `SP500.DWX` (slot 2) — S&P 500 (backtest-only custom symbol), US SEC settlement era table.
- `WS30.DWX` (slot 3) — Dow 30, US SEC settlement era table.

**Explicitly NOT for:**
- Any FX pair — this is an equity-index settlement-flow effect, not applicable to currency pairs.
- `SPY.DWX` / `SPX500.DWX` / `ES.DWX` — not registered Custom Symbols; `SP500.DWX` is the sole S&P 500 route.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none — each symbol trades its own D1 stream with broker-time month boundaries |
| Bar gating | `QM_IsNewBar()` (default, single-consume per OnTick) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 (one settlement-trough long per calendar month) |
| Expected trade frequency | About 12 long turn-of-month events/year/symbol; the Q02 floor of five completed trades/year/symbol should clear. |
| Typical hold time | ~6-7 calendar days (trough entry through T+3 of the new month, incl. a weekend) |
| Expected drawdown profile | ~15% (expected_dd_pct, card frontmatter) |
| Regime preference | calendar-seasonality / turn-of-month liquidity flow |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ETULA-DASHFORCASH-TOM-2020`
**Source type:** paper
**Pointer:** DOI 10.1093/rfs/hhz054; https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2528692
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_20026_tom-settlement-trough.md`

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
| v1 | 2026-07-21 | Initial build from card | f77b622a-a6a9-43ff-8fba-e4d5edd15687 |
