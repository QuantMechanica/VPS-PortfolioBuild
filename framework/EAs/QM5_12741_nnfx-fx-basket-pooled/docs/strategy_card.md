---
ea_id: QM5_12741
slug: nnfx-fx-basket-pooled
type: strategy
source_id: nnfx-vp-canonical-2026-06-12
sources:
  - "[[sources/no-nonsense-forex]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/indicator-stack-confirmation]]"
  - "[[concepts/atr-risk]]"
  - "[[concepts/multi-symbol-basket]]"
indicators:
  - "[[indicators/kijun-sen]]"
  - "[[indicators/ssl-channel]]"
  - "[[indicators/aroon]]"
  - "[[indicators/waddah-attar-explosion]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "VP / No Nonsense Forex published algorithm (nononsenseforex.com); same canonical source as QM5_12534. Basket realization, not a new edge claim."
r2_mechanical: PASS
r2_reasoning: "Deterministic NNFX stack (Kijun baseline + SSL C1 + Aroon C2 + WAE volume gate + 1.5xATR SL / 1xATR half-TP + runner), applied independently per member symbol on D1, single magic, ONE pooled trade stream. Closed-bar rules only."
r3_data_available: PASS
r3_reasoning: "4 liquid .DWX FX majors with full D1 history; no external data."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed-parameter indicator stack; no ML, no optimization-adaptive logic, no martingale; bounded per-symbol risk."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 3
expected_pf: 1.30
expected_dd_pct: 12
last_updated: 2026-06-28
g0_approval_reasoning: "G0 2026-06-28 Claude (OWNER-directed NNFX sweep). The 4-agent NNFX audit proved the classical single-pair NNFX family is structurally dead in V5: NOT due to banned indicators (the legal canonical stack QM5_12534 is faithful) but because the 5-filter D1 AND-gate starves cadence to ~2-3 trades/yr/symbol, which mathematically cannot fill Q04's 3 one-year OOS folds. This card attacks the ROOT CAUSE: run the legal 12534 stack as a MULTI-SYMBOL BASKET over the only gross-positive majors and evaluate the POOLED trade stream (~12-14 trades/yr aggregate) as ONE trend-following sleeve, clearing the DL-070/DL-076 low-freq pooled-trade floors. Strategic value: the live 13-book is ~9/13 mean-reversion with only ~1 trend sleeve, so a working pure-trend FX sleeve is maximally uncorrelated (book gap). This is the single bounded NNFX experiment; if the pooled stream cannot show a real net-of-cost edge through Q04 AND improve book Sharpe under DL-079, the NNFX family is permanently closed."
---

# NNFX FX Basket - pooled trend sleeve (faithful VP stack)

## Source
VP, "No Nonsense Forex" - published algorithm (nononsenseforex.com). Same canonical
stack as QM5_12534; this is the BASKET realization.

## Why this card exists
Single-pair NNFX dies because the D1 5-filter AND-gate fires only ~2-3x/yr/symbol -
too sparse for Q04's per-fold floor (proven across QM5_2001-2014 + 12534, all Q04 FAIL
with 0-1-trade folds). Per-symbol gross results for 12534 show only **4 of 9 majors are
gross-positive**: AUDUSD (Q02 PF 1.62), EURUSD (1.66), GBPUSD (2.30), USDCHF (1.42);
the other 5 are PF<1 and would only drag a pool. Pooling these 4 into ONE sleeve gives
~12-14 trades/yr aggregate - enough to be evaluated as a single low-freq trend sleeve.

## Strategy (build spec)
- **Pattern:** multi-symbol single-host basket. Model the build on **QM5_2012**
  (nnfx-v2-fx-basket-top3-trend) for basket order routing + **QM5_10717** (edgelab
  basket reference) for single-host structure; use **QM5_12534**'s exact indicator logic
  for the per-symbol signal. Use `QM_BasketOrder.mqh` (single magic, per-symbol slots).
- **Members (4):** AUDUSD.DWX, EURUSD.DWX, GBPUSD.DWX, USDCHF.DWX. Symbol slots 0-3.
- **Timeframe:** D1 (NNFX doctrine; reject non-D1 like 12534's `Strategy_NoTradeFilter`).
- **Per-symbol signal (identical to QM5_12534):** Kijun(26) baseline direction + SSL(10)
  C1 + Aroon(25) C2 agreement + Waddah-Attar Explosion volume gate; entry on the close
  the stack aligns within a 3-bar window; 1x ATR proximity gate.
- **Money management:** RISK_FIXED for backtest; 1.5xATR initial SL, half-close at 1xATR
  then runner to breakeven; per-symbol risk bounded; ONE magic = pooled stream so Q08/
  portfolio reads the basket as a single sleeve.
- **Hard rules:** news-blackout filter ON; no ML; no martingale/grid; closed-bar only.

## Acceptance
Q02 (pooled gross PF >= 1.20 + pooled trade floor), then full Qxx. The decisive test is
Q04 walk-forward on the POOLED stream (the gate single-pair NNFX cannot pass) and Q08 +
DL-079 admission vs the live book. Diversification target: low correlation to the
mean-reversion-heavy 13-book (it is a pure-trend FX sleeve).
