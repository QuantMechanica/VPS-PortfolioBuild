# QM5_11539_carter-t-h1-ema5-10-rsi10-median — Strategy Spec

**EA ID:** QM5_11539
**Slug:** `carter-t-h1-ema5-10-rsi10-median`
**Source:** `3001a121-97a0-5db0-b6ff-69b89a0fc07d` (Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", System #13)
**Author of this spec:** Codex
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

On the close of each H1 bar the EA looks for two events pointing the same way: an
EMA(5)/EMA(10) close-price cross and a cross of RSI(10) applied to the median
price (H+L)/2 through the 50 midline. It goes long when EMA(5) crosses above
EMA(10) and RSI(10, median) crosses up through 50; it goes short on the mirror
condition. The two crosses do not have to land on the same bar — they only have
to be synchronized within a +/-2 bar window. The rule is codified as: the later
of the two cross events must complete on the just-closed bar (shift 1), and the
other cross must have completed on that same bar or within the preceding
`strategy_sync_window` (2) bars; whichever event completes later fires the entry,
so a signal triggers exactly once per synchronized pair. Only one position is
held per symbol at a time. Positions carry a fixed 30-pip stop loss and 50-pip
take profit and have no discretionary exit — they close on SL/TP or the
framework Friday-close sweep. New entries are suppressed on Fridays (broker time)
and whenever the live spread exceeds 15 pips (the .DWX tester spread is 0, so the
spread gate is a live-only guard).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast` | 5 | 3-10 | Fast EMA period (PRICE_CLOSE). |
| `strategy_ema_slow` | 10 | 5-20 | Slow EMA period (PRICE_CLOSE). |
| `strategy_rsi_period` | 10 | 7-14 | RSI period, applied to PRICE_MEDIAN (H+L)/2. |
| `strategy_rsi_level` | 50.0 | 40-60 | RSI midline the oscillator must cross. |
| `strategy_sync_window` | 2 | 1-3 | Max bars allowed between the EMA cross and the RSI cross. |
| `strategy_sl_pips` | 30 | 20-35 | Fixed stop-loss distance in pips (P2 cap 35). |
| `strategy_tp_pips` | 50 | 40-60 | Fixed take-profit distance in pips. |
| `strategy_spread_cap_pips` | 15 | 5-20 | Block a new entry if the live spread exceeds this many pips. |
| `strategy_block_friday_entry` | 1 | 0-1 | 1 = no new entries on Friday (broker time); 0 = allow. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_*, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*) are
> documented in `framework/V5_FRAMEWORK_DESIGN.md` — not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Deepest, tightest major FX pair; 5-digit non-JPY quote so the
  30/50-pip fixed stops translate cleanly. Registered at slot 0 (magic 115390000).
- `GBPUSD.DWX` — Liquid major with enough intraday trend/range on H1 for a fast
  EMA(5/10) cross to work; 5-digit non-JPY quote, same pip scale. Registered at
  slot 1 (magic 115390001).

**Explicitly NOT for:**
- JPY crosses and other 3-digit quotes — the fixed pip stops assume a 5-digit
  scale and the source calibrated the system on standard FX majors.
- Metals / indices / crypto — the fixed-pip SL/TP and the RSI-median midline
  behaviour are not calibrated for those volatility regimes.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 30 (Q02 requires at least 5/year) |
| Typical hold time | hours to a few days, capped by the 50-pip TP / 30-pip SL |
| Expected drawdown profile | clustered losses in choppy, non-trending regimes when crosses whipsaw; ~16% expected DD |
| Regime preference | trend / momentum (EMA cross confirmed by an RSI momentum thrust) |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3001a121-97a0-5db0-b6ff-69b89a0fc07d`
**Source type:** book
**Pointer:** Thomas Carter, *20 Forex Trading Strategies (1 Hour Time Frame)*, self-published 2014, System #13; approved card at `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11539_carter-t-h1-ema5-10-rsi10-median.md`.
**R1–R4 verdict (Q00):** APPROVED (R1 TIER_C informational; R2/R3/R4 PASS) — see `artifacts/cards_approved/QM5_11539_carter-t-h1-ema5-10-rsi10-median.md`.

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
| v1 | 2026-08-10 | Initial build from card | task 5ea0928f-8919-4fa1-adbd-c954d40b6495 |
