# QM5_11455_davey-donchian-close-breakout — Strategy Spec

**EA ID:** QM5_11455
**Slug:** `davey-donchian-close-breakout`
**Source:** `3831c272-c52f-57c3-a857-2ab252e33bb0` (see `strategy-seeds/sources/3831c272-c52f-57c3-a857-2ab252e33bb0/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

Close-vs-close Donchian channel breakout. Long when today's closed D1 bar
(`Close[1]`) is greater than or equal to the highest close of the prior
`strategy_length` bars (bars `[2..length+1]`) — a new N-bar closing high built
from sustained directional closes rather than intraday wicks. Short is the
mirror on a new N-bar closing low. Entry fires at market on the open of the
next D1 bar. Exit is ATR(14)-scaled: SL = `ATR(14)[1] * strategy_atr_sl_mult`
(capped at `strategy_sl_cap_pips`), TP = `ATR(14)[1] * strategy_atr_tp_mult`.
An opposite-direction closing extreme closes the open position and reverses
(the exit check runs immediately before the entry check in `OnTick`, so the
new opposite position can open in the same tick once flat).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_length` | 20 | 10-200 | Donchian close lookback (P3 sweeps 10/20/55/200) |
| `strategy_atr_period` | 14 | fixed | ATR period for SL/TP scaling |
| `strategy_atr_sl_mult` | 1.5 | 1.0-2.0 | ATR multiple for stop-loss distance |
| `strategy_atr_tp_mult` | 3.0 | 2.0-5.0 | ATR multiple for take-profit distance |
| `strategy_sl_cap_pips` | 120 | fixed | Hard cap on the ATR-derived SL distance |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major, D1 close-breakout regime present
- `GBPUSD.DWX` — liquid major
- `USDJPY.DWX` — liquid major
- `AUDUSD.DWX` — liquid major, commodity-FX trend behaviour
- `USDCAD.DWX` — liquid major, commodity-FX trend behaviour

**Explicitly NOT for:**
- Illiquid crosses / exotics — card's R3 basket is limited to the five DWX
  FX majors listed above; no D1 close-breakout edge has been asserted beyond
  that basket.

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
| Trades / year / symbol | 8-20 |
| Typical hold time | days (until opposite signal, TP, or SL) |
| Expected drawdown profile | trend-following whipsaw risk in ranging regimes |
| Regime preference | trend / breakout |
| Win rate target (qualitative) | low-medium (trend system, large avg winner) |

---

## 6. Source Citation

**Source ID:** `3831c272-c52f-57c3-a857-2ab252e33bb0`
**Source type:** book
**Pointer:** Kevin J. Davey, "My 5 Favorite Entries", KJ Trading Systems (local PDF: 374755020-My-5-Favorite-Entries.pdf)
**R1–R4 verdict (Q00):** R1 TIER_C (informational, non-gating), R2/R3/R4 PASS — see `artifacts/cards_approved/QM5_11455_davey-donchian-close-breakout.md`

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
| v1 | 2026-08-10 | Initial build from card | build_ea task 22d3a361-f77f-483b-9837-875fef523a26 |
