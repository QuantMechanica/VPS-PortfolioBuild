# QM5_11457_goodwin-6day-extreme-3day-stop-entry-d1 — Strategy Spec

**EA ID:** QM5_11457
**Slug:** `goodwin-6day-extreme-3day-stop-entry-d1`
**Source:** `545042dd-9b9a-5428-a067-d60fdae46c08` (see `strategy-seeds/sources/545042dd-9b9a-5428-a067-d60fdae46c08/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

Mean-reversion via a stop-order entry. When today's closed D1 bar
(`Close[1]`) sets a new `strategy_extreme_lookback`-bar (6) closing low, place
a BUYSTOP at the `strategy_stop_lookback`-bar (3) closing high — enter only
once price actually starts recovering, not at the extreme itself. Short is
the mirror (new 6-bar closing high -> SELLSTOP at the 3-bar closing low). The
pending stop order is cancelled and re-placed at an updated price every new
D1 bar the setup condition still holds. Once filled, SL/TP are ATR(14)-scaled
(SL capped at `strategy_sl_cap_pips`), and the position is force-closed after
`strategy_hold_bars` (4) additional closed bars regardless of P&L — Goodwin's
original system has no protective stop and relies on the time exit; the ATR
SL/TP here are a V5 risk-model addition per the card. This is an exploratory
FX port of an S&P-500-futures system (source R1 is informational only).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_extreme_lookback` | 6 | 4-10 | N-bar closing extreme that triggers the setup |
| `strategy_stop_lookback` | 3 | 2-5 | N-bar closing extreme used as the stop-order price |
| `strategy_hold_bars` | 4 | 3-7 | Bars held since entry before forced time exit (5-bar total hold) |
| `strategy_atr_period` | 14 | fixed | ATR period for SL/TP scaling |
| `strategy_atr_sl_mult` | 1.5 | fixed | ATR multiple for stop-loss distance |
| `strategy_atr_tp_mult` | 2.0 | fixed | ATR multiple for take-profit distance |
| `strategy_sl_cap_pips` | 100 | fixed | Hard cap on the ATR-derived SL distance |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX` — the
  card's R3 basket; original system was backtested on S&P 500 futures, this
  is an exploratory FX adaptation to be confirmed at Q02/Q03.

**Explicitly NOT for:**
- Any symbol outside the five listed DWX FX majors — no R3 basis asserted.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 5-12 |
| Typical hold time | up to 5 D1 bars (time-exit bound) |
| Expected drawdown profile | mean-reversion — frequent small losses, occasional larger ATR-TP winners |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `545042dd-9b9a-5428-a067-d60fdae46c08`
**Source type:** book
**Pointer:** Andrew Goodwin, "Trading Secrets of the Inner Circle", Market Place Books, 1997 (local PDF: "Trading Secrets of the Inner Circle (Andrew Goodwin) (Z-Library).pdf")
**R1–R4 verdict (Q00):** R1 PASS (informational per OWNER 2026-07-23 policy), R2/R3/R4 PASS — see `artifacts/cards_approved/QM5_11457_goodwin-6day-extreme-3day-stop-entry-d1.md`

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
| v1 | 2026-08-10 | Initial build from card | build_ea task 3d6528b3-867e-49d7-b359-3ea00ab4137d |
| v2 | 2026-08-12 | Strict performance-contract repair | Documented the four bounded D1 close reads as new-bar-gated; trading mechanics and parameters are unchanged. |
