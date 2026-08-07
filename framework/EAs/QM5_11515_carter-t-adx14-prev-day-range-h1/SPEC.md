# QM5_11515_carter-t-adx14-prev-day-range-h1 — Strategy Spec

**EA ID:** QM5_11515
**Slug:** `carter-t-adx14-prev-day-range-h1`
**Source:** `8794b680-f6f4-5142-b12c-e5e0057e7bcf`
**Author of this spec:** Codex
**Last revised:** 2026-08-07

---

## 1. Strategy Logic

On each new H1 bar, the EA reads ADX(14) and the last closed broker-day range. When ADX is below 35 and the last closed H1 candle traded at least 15 pips below the prior-day low, it stages a BuyStop 15 pips above the prior-day high. The short rule is mirrored: a candle at least 15 pips above the prior-day high stages a SellStop 15 pips below the prior-day low. Each order expires at broker-day end, uses a 30-pip stop and 60-pip target, and any filled position still open after its entry day is closed on the first next-day tick; no new orders are staged on Friday.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_adx_period` | 14 | 14 (card-fixed) | H1 ADX period used for the rangebound filter. |
| `strategy_adx_threshold` | 35.0 | 25.0–35.0 | Entry is allowed only when closed-bar ADX is below this level. |
| `strategy_false_break_pips` | 15 | 10–20 | Distance beyond a prior-day extreme required to arm the opposite-side stop. |
| `strategy_entry_offset_pips` | 15 | 10–20 | Distance beyond the opposite prior-day extreme used for the pending entry. |
| `strategy_stop_loss_pips` | 30 | 20–40 | Fixed stop distance from the pending entry price. |
| `strategy_take_profit_rr` | 2.0 | 2.0 (source ratio) | Take-profit distance as a multiple of initial stop risk. |
| `strategy_max_spread_pips` | 15 | 15 (card-fixed) | Maximum genuine bid/ask spread; zero modeled DWX spread is allowed. |

Framework-level risk, news, stress, and Friday-close inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid major FX pair with the H1 and D1 history required by the card.
- `GBPUSD.DWX` — liquid major FX pair with the H1 and D1 history required by the card.
- `AUDUSD.DWX` — liquid major FX pair with the H1 and D1 history required by the card.

**Explicitly NOT for:**

- Bare broker symbols such as `EURUSD` — research and backtests must use the registered `.DWX` aliases; live-symbol mapping is a separate deploy step.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` — no deterministic tester data is available for them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | Prior broker-day High/Low from `D1`, shift 1 |
| Bar gating | `QM_IsNewBar()` on the H1 tester chart |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | About 50 |
| Expected trade frequency | About weekly per symbol, derived from the card's 50 trades/year estimate |
| Typical hold time | Intraday; no longer than the broker day of entry |
| Expected drawdown profile | Not quantified by the card; each trade is bounded by the 30-pip server-side stop and framework risk sizing |
| Regime preference | Low-ADX range conditions followed by a false break and opposite-range breakout |
| Win rate target (qualitative) | Not specified by the card |

---

## 6. Source Citation

This card was mechanised from Thomas Carter, *Forex Trend Following Strategies: 20 Trend Following Systems*, System #11, self-published 2014.

**Source ID:** `8794b680-f6f4-5142-b12c-e5e0057e7bcf`
**Source type:** book
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11515_carter-t-adx14-prev-day-range-h1.md`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11515_carter-t-adx14-prev-day-range-h1.md`.

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
| v1 | 2026-08-07 | Initial build from card | 266038fd-a7dd-4d96-a4a8-6e0eb3f90515 |
