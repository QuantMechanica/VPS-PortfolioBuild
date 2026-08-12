# QM5_11533_carter-t-h1-ema3-5-13-21-80-rsi21 — Strategy Spec

**EA ID:** QM5_11533
**Slug:** `carter-t-h1-ema3-5-13-21-80-rsi21`
**Source:** `3001a121-97a0-5db0-b6ff-69b89a0fc07d` (see `strategy-seeds/sources/3001a121-97a0-5db0-b6ff-69b89a0fc07d/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

Five-EMA ribbon trend-following system with RSI confirmation. Long when the
fast EMA(3) crosses above EMA(5) on a closed H1 bar, both EMA(3) and EMA(5)
are positioned above EMA(13) and EMA(21) (medium-term confirmation), EMA(13)
and EMA(21) both sit above EMA(80) (structural baseline filter), and RSI(21)
is above 50. Short is the full mirror. No Friday-setup entries. Exit is
purely indicator-driven: close the position when EMA(3) recrosses EMA(5)
against the trade direction, or RSI(21) recrosses 50 against the trade
direction — whichever comes first. A fixed `strategy_sl_pips` protects
against a stalled indicator exit; there is no discretionary take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast` | 3 | fixed | Fast EMA period (cross trigger) |
| `strategy_ema_signal` | 5 | fixed | Signal EMA period (cross trigger) |
| `strategy_ema_medium1` | 13 | fixed | Medium EMA #1 (confirmation + structural filter reference) |
| `strategy_ema_medium2` | 21 | fixed | Medium EMA #2 (confirmation + structural filter reference) |
| `strategy_ema_baseline` | 80 | fixed | Structural baseline EMA |
| `strategy_rsi_period` | 21 | 14-21 | RSI confirmation period (P3 sweeps 14/21) |
| `strategy_rsi_threshold` | 50.0 | fixed | RSI confirmation/exit threshold |
| `strategy_sl_pips` | 25 | 20-30 | Fixed stop-loss distance (P2 fallback; card gives 20-30 pip range) |
| `strategy_max_spread_pips` | 15 | fixed | Spread cap blocking fresh entries only |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — the card's sole R3 basis; System #7 from Carter's H1 book was
  developed and cited for this pair only.

**Explicitly NOT for:**
- Any other symbol — no R3 basket beyond EURUSD.DWX has been asserted for this card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~10 |
| Typical hold time | hours (until reverse cross or RSI recross) |
| Expected drawdown profile | trend system — whipsaw risk when ribbon flattens in chop |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `3001a121-97a0-5db0-b6ff-69b89a0fc07d`
**Source type:** book (self-published)
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", self-published 2014, System #7
**R1–R4 verdict (Q00):** R1 TIER_C (informational, self-published, non-gating), R2/R3/R4 PASS — see `artifacts/cards_approved/QM5_11533_carter-t-h1-ema3-5-13-21-80-rsi21.md`

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
| v1 | 2026-08-10 | Initial build from card | build_ea task abfb4871-b012-4a57-b800-47e73a63e647 |
