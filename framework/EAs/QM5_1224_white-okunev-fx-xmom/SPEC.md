# QM5_1224_white-okunev-fx-xmom — Strategy Spec

**EA ID:** QM5_1224
**Slug:** `white-okunev-fx-xmom`
**Source:** `afab7a6f-c3c8-51ae-a609-f376744beb8e`
**Author of this spec:** Codex
**Last revised:** 2026-07-20

---

## 1. Strategy Logic

One `EURUSD.DWX` D1 host evaluates a seven-pair USD-cross universe as a single
logical basket. At the first D1 bar of each month, it scores the last closed bar
for every currency as `Close / SMA(Close, 120) - 1`. Scores for USD-base pairs
are sign-inverted so positive always means that the non-USD currency is strong
against USD. The EA buys the strongest foreign currency and sells the weakest,
using the correct direction of each tradable pair.

At each later monthly rebalance, a leg is retained while its currency remains in
the relevant top/bottom-two rank band. A missing side is replaced with the
current strongest or weakest currency. If fewer than five symbols have aligned,
valid history, the whole package is closed. Every leg receives a hard
`3 × ATR(D1, 20)` stop, and the complete basket is flattened if combined open
P/L reaches `-2R`, where one R is the effective per-leg risk budget.

The package is atomic: exactly one foreign-currency long and one
foreign-currency short must exist. A failed second order, invalid composition,
or orphaned leg triggers compensating closure. Friday close is deliberately
disabled because a weekly flatten would contradict the source's monthly
rank-retention rule.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_sma_period_d1` | 120 | 20–400 | D1 simple-moving-average lookback used in the rank score. |
| `strategy_min_d1_bars` | 160 | 160–600 | Minimum aligned D1 history required per valid universe member. |
| `strategy_exit_rank_band` | 2 | 1–3 | Top/bottom band in which an existing leg may be retained. |
| `strategy_atr_period` | 20 | 5–100 | D1 ATR lookback for the hard stop. |
| `strategy_atr_sl_mult` | 3.0 | greater than 0–10 | ATR multiple for each leg's stop. |
| `strategy_basket_loss_r` | 2.0 | greater than 0–10 | Combined open-loss limit in effective per-leg R units. |
| `strategy_rebalance_mode` | 1 | 0–1 | `0` weekly research cadence; `1` approved monthly baseline. |
| `strategy_spread_days` | 20 | 1–64 | D1 spread observations used for the execution guard. |
| `strategy_spread_mult` | 3.0 | greater than 0–10 | Maximum current spread as a multiple of its median. |

---

## 3. Symbol Universe

**Designed for one logical package:**

- `EURUSD.DWX` — slot 0 and the only valid D1 tester host.
- `GBPUSD.DWX` — slot 1 rank member and possible traded leg.
- `AUDUSD.DWX` — slot 2 rank member and possible traded leg.
- `NZDUSD.DWX` — slot 3 rank member and possible traded leg.
- `USDCAD.DWX` — slot 4, sign-adjusted because USD is the base currency.
- `USDCHF.DWX` — slot 5, sign-adjusted because USD is the base currency.
- `USDJPY.DWX` — slot 6, sign-adjusted because USD is the base currency.

**Explicitly NOT for:**

- Any standalone pair/chart test — a single component has no cross-sectional
  long/short decision and is not an economically valid strategy unit.
- Non-DWX or non-USD crosses — the approved score normalization and magic-slot
  contract cover only the seven symbols above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | one `QM_IsNewBar()` call on the `EURUSD.DWX` D1 host |
| Calendar gating | current and previous `QM_CalendarPeriodKey` values; no synthetic MN1 history |
| Decision data | aligned closed D1 bars (`shift=1`) across all valid members |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Logical decisions / year | 12 monthly rank observations at baseline |
| New leg entries / year | approximately 2–24, depending on rank persistence |
| Typical hold time | weeks to months |
| Expected drawdown profile | two-sided FX exposure with two hard ATR stops and a combined loss rail |
| Regime preference | persistent cross-sectional currency trends |
| Win rate target (qualitative) | medium; payoff comes from relative trend persistence |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `afab7a6f-c3c8-51ae-a609-f376744beb8e`
**Source type:** academic paper
**Pointer:** Derek R. White and John Okunev, *Do Momentum Based Strategies
Still Work in Foreign Currency Markets?* (2001), SSRN abstract 264574; approved
card at `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1224_white-okunev-fx-xmom.md`
**R1–R4 verdict (Q00):** approved; deterministic moving-average rank rules,
DWX major-FX data, and no ML, grid, or martingale mechanics.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02–Q10) | RISK_FIXED | $500 per leg; $1,000 total initial package stop risk |
| Live burn-in (Q13) | RISK_PERCENT | card value 0.125% per leg, subject to OWNER-approved deployment preset |
| Full live (post-Q13 PASS) | RISK_PERCENT | allocated by Q11 portfolio; no value authorized by this repair |

The `RISK_FIXED=500`, `RISK_PERCENT=0` logical Q02 preset is the only preset
created by this repair. Risk-mode validation remains enforced by
`QM_FrameworkInit`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-26 | Initial per-chart build | Later found invalid for cross-sectional testing. |
| v2 | 2026-07-20 | Q02 infrastructure repair | Converted seven component instances into one atomic logical basket. |
