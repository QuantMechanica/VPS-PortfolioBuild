# QM5_12401_mom-vol-rev — Strategy Spec

**EA ID:** QM5_12401
**Slug:** `mom-vol-rev`
**Source:** `b7832a20-938e-5f24-b9d7-e0b2ab63b623` (Papers With Backtest / Quantpedia — "Momentum and Reversal Combined with Volatility Effect in Stocks")
**Author of this spec:** Codex
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

Monthly cross-sectional momentum/reversal over a fixed multi-asset CFD basket, run
one-instance-per-symbol. At the start of each calendar month, every instance
deterministically recomputes the SAME full-basket ranking: for each basket symbol
with enough closed D1 history, it skips the most-recent `strategy_skip_d1` (5) D1
bars, then computes a 6-month (`strategy_lookback_d1` = 126-bar) return and the
annualized realized volatility of the daily log returns over that same window. The
`strategy_vol_subset_size` (4) highest-volatility symbols form the "high-vol subset";
inside that subset the `strategy_breadth` (1) strongest 6-month performer is bought
and the weakest is sold. Each instance then acts only on its OWN chart symbol's
resulting long / short / flat state. Because the computation is deterministic and
every instance sees the same basket data, the cross-sectional selection is
reproduced without any cross-instance coordination.

Rebalance cadence is NON-OVERLAPPING monthly — a sanctioned literal reading of the
card's own fallback clause ("If implementing one-position-per-magic cannot represent
overlapping sleeves safely, Q01 should use a non-overlapping monthly rebalance
variant and mark the tranche approximation in the spec."). The card's nominal 6-month
overlapping-tranche holding (6 concurrent sleeves per symbol) is NOT modelled; one
position per magic is re-evaluated each month via `QM_IsNewCalendarPeriod(PERIOD_MN1)`
/ `QM_CalendarPeriodKey(PERIOD_MN1)`: close this symbol's leg if the new rank no
longer selects it in the same direction, hold if still selected same direction, open
if newly selected. This is a tranche approximation, documented per the card clause.

Per-leg emergency stop is a server-side SL at `strategy_atr_sl_mult * ATR(strategy_atr_period)`
(3 * ATR(20)) set at entry. A basket-level aggregate stop closes ALL legs owned by
this ea_id when combined floating PnL falls below `-strategy_basket_stop_r_mult` (6) * R,
via the framework's cross-magic `QM_BasketEquityStop_*` primitives. Entry is skipped
when the modeled spread exceeds `strategy_spread_mult` (2) * the rolling 60-day median
spread, and blocked until the full available basket has valid return/volatility data.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_d1` | 126 | 84-252 | Return/volatility lookback in D1 bars (~6 months). |
| `strategy_skip_d1` | 5 | 0-10 | Most-recent D1 bars skipped before the lookback window. |
| `strategy_vol_subset_size` | 4 | 2-8 | Size of the highest-volatility subset selected from the basket. |
| `strategy_breadth` | 1 | 1-3 | Number of symbols bought (strongest) and sold (weakest) inside the subset. |
| `strategy_min_valid_symbols` | 7 | 1-7 | Symbols that must have valid metrics before any trade fires. |
| `strategy_warmup_bars` | 140 | 130-400 | Minimum host D1 bars before trading. |
| `strategy_atr_period` | 20 | 10-30 | ATR period for the per-leg emergency stop. |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | Per-leg emergency stop distance = mult * ATR. |
| `strategy_median_spread_lookback` | 60 | 20-120 | Rolling median-spread window in D1 bars. |
| `strategy_spread_mult` | 2.0 | 1.5-3.0 | Skip entry when spread > mult * median spread. |
| `strategy_basket_stop_r_mult` | 6.0 | 3.0-10.0 | Basket aggregate stop threshold = -mult * R (cross-magic). |

---

## 3. Symbol Universe

Cross-sectional basket — the EA is designed to run as one instance per symbol across
the whole basket simultaneously (each instance recomputes the same ranking).

**Designed for (registered magic slots 0-6):**
- `SP500.DWX` — S&P 500 index CFD; US large-cap leg of the global basket.
- `NDX.DWX` — Nasdaq 100 index CFD; US growth/tech leg.
- `WS30.DWX` — Dow 30 index CFD; US large-cap value leg.
- `GDAXI.DWX` — DAX 40 index CFD; EU leg (port of the card's `GER40.DWX`, which is
  not a matrix symbol — `GDAXI.DWX` is the canonical DAX 40 Custom Symbol).
- `UK100.DWX` — FTSE 100 index CFD; UK leg.
- `XAUUSD.DWX` — gold; metals leg, high-volatility diversifier.
- `XTIUSD.DWX` — WTI crude oil; energy leg, high-volatility diversifier.

**Explicitly NOT for:**
- `JP225.DWX` — the card lists it, but there is no Japanese/Asian index in
  `dwx_symbol_matrix.csv` and no acceptable correlated CFD port exists, so it is
  dropped; the basket runs at 7 symbols instead of 8 (see Source Citation and the
  build open_questions). Single-symbol technical EAs — this is a portfolio-ranking EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | Cross-symbol D1 reads for all 7 basket symbols (via `QM_BasketWarmupHistory` + gated `CopyClose`) |
| Bar gating | `QM_IsNewBar()` for entry; `QM_IsNewCalendarPeriod` / `QM_CalendarPeriodKey(PERIOD_MN1)` for the monthly rebalance |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 3 |
| Typical hold time | about one month per leg (non-overlapping monthly rebalance) |
| Expected drawdown profile | material; roughly 22% expected DD — a high-turnover long/short factor with regime risk |
| Regime preference | cross-sectional momentum/reversal on the high-volatility subset |
| Win rate target (qualitative) | low/medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b7832a20-938e-5f24-b9d7-e0b2ab63b623`
**Source type:** paper / catalog implementation
**Pointer:** Papers With Backtest / Quantpedia implementation, "Momentum and Reversal
Combined with Volatility Effect in Stocks" (awesome-systematic-trading catalog).
**R1-R4 verdict (Q00):** R1 lineage recorded and R2-R4 PASS per
`artifacts/cards_approved/QM5_12401_mom-vol-rev.md`.

Deviations from the card, all sanctioned by the card's own fallback text or by DWX
symbol discipline, recorded here and in the build open_questions:
- Non-overlapping monthly rebalance instead of 6 overlapping tranches (card fallback).
- `GER40.DWX` -> `GDAXI.DWX`; `JP225.DWX` dropped (no matrix equivalent), basket = 7.
- `strategy_breadth` and `strategy_vol_subset_size` had no stated P2 default; set to
  1 and 4 (half the nominal 8-symbol basket) as the simplest literal baseline.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (0.25% for this EA per card) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-10 | Initial build from card | task 581a9957-4c0b-47f8-9b4c-f9b373d9fcb2 |
