# Century-Suite Reserved EA IDs Audit — 18 IDs (QM5_30001–QM5_41012)

**Date:** 2026-08-17  
**Agent:** Gemini (Deterministic Strategy Farm Orchestration)  
**Task ID:** `af9a3a11-3596-4f90-a977-914d7ad5d087`  
**Reference Document:** `decisions/2026-08-15_century_suite_intake_triage.md`  
**Target IDs (18):** QM5_30004, QM5_30007, QM5_31001, QM5_31008, QM5_32002, QM5_32004, QM5_32005, QM5_32006, QM5_34002, QM5_40001, QM5_40003, QM5_40004, QM5_40006, QM5_40007, QM5_41004, QM5_41007, QM5_41008, QM5_41012.

---

## 1. Executive Summary

Of the 100 reserved IDs in the Century Suite (`QM5_30001`–`QM5_41012`), exactly 82 cards are approved in `strategy-seeds/cards/approved/` and `D:/QM/strategy_farm/artifacts/cards_approved/`.

The 18 IDs without an approved strategy card were audited against the canonical G0 intake decision record (`decisions/2026-08-15_century_suite_intake_triage.md`) and `framework/registry/ea_id_registry.csv`.

### Breakdown by Category
- **Category 1: Deliberately Dropped / Rejected:** **16**
- **Category 2: Deliberately Deferred:** **2**
- **Category 3: Genuinely Missing / Unwritten Cards:** **0**

**Conclusion:** No card was omitted or accidentally lost. Zero (0) new cards should be authored. Authoring cards for these IDs would violate explicit G0 rejection decisions (ML prohibition, closed strategy lines, unmapped instruments, duplicate strategies) or bypass active correlation hold policies.

---

## 2. Category 1: Deliberately Dropped / Rejected (16 IDs)

All 16 IDs below have status `retired` in `framework/registry/ea_id_registry.csv` and were rejected during G0 triage on 2026-08-15.

| EA ID | Strategy Name | Reason Class | Specific Rejection Reason | Registry Status |
|---|---|---|---|---|
| **QM5_30004** | `ann-filtered-multipair-grid-perceptrader-ai` | R4 Hard Rule | Feedforward ANN filter = ML forbidden (card self-declares FAIL) | `retired` |
| **QM5_30007** | `ai-sentiment-price-action-infinity-trader` | R4 Hard Rule | LLM sentiment module = ML/LLM forbidden (self-declared FAIL) | `retired` |
| **QM5_40006** | `tradingview-lorentzian-distance-knn-classifier` | R4 + R3 | Lorentzian KNN classifier = ML forbidden; BTC/ETH not in DWX universe | `retired` |
| **QM5_31001** | `smc-london-silver-bullet` | Closed Line | ICT Silver Bullet retired 2026-06-27 (no mechanical edge); SMC/ICT family closed | `retired` |
| **QM5_31008** | `gold-reaper-order-block-mitigation` | Closed Line | Gold Reaper do-not-clone (vol-gated EOD-flat already ported as QM5_20007) | `retired` |
| **QM5_32005** | `rty-small-cap-mean-reversion-scalper` | R3 (Universe) | Russell 2000 not in DWX universe, no instrument mapping | `retired` |
| **QM5_32006** | `btcusd-weekend-range-monday-breakout` | R3 (Universe) | BTCUSD not in DWX universe | `retired` |
| **QM5_34002** | `brent-wti-crude-statistical-arbitrage` | R3 (Universe) | Brent leg unavailable in DWX feed; two-leg cointegration unbuildable | `retired` |
| **QM5_41007** | `vix-volatility-spike-equity-reversion` | R3 (Feed) | No VIX feed in MT5/DWX universe | `retired` |
| **QM5_41008** | `commodity-carry-roll-yield-arbitrage` | R3 (Feed) | Roll-yield requires futures-curve data absent from CFD feed | `retired` |
| **QM5_40001** | `quantpedia-turn-of-the-month-anomaly` | Duplicate | Turn-of-month = Duplicate of approved QM5_1049 | `retired` |
| **QM5_40003** | `alvarez-connors-rsi2-mean-reversion` | Duplicate | Connors RSI(2) = Duplicate of QM5_10429 / QM5_10523 (SP500+NDX covered) | `retired` |
| **QM5_40004** | `alvarez-cumulative-rsi2-volatility-dip` | Duplicate | Cumulative RSI(2) = Duplicate of QM5_10430 (SP500+NDX covered) | `retired` |
| **QM5_40007** | `aqr-time-series-momentum-tsmom` | Duplicate | AQR TSMOM = Duplicate of QM5_1056 `moskowitz-tsmom-multiasset` | `retired` |
| **QM5_41004** | `golden-cross-50-200-volatility-trail` | Duplicate | Golden Cross 50/200 = Duplicate of QM5_10114 | `retired` |
| **QM5_41012** | `john-carter-ttm-squeeze-momentum` | Duplicate | TTM Squeeze = Duplicate of QM5_10395 | `retired` |

---

## 3. Category 2: Deliberately Deferred (2 IDs)

These 2 IDs have status `allocated` in `framework/registry/ea_id_registry.csv` and are held under active risk / correlation caps.

| EA ID | Strategy Name | Deferral Reason | Registry Status | Next Action |
|---|---|---|---|---|
| **QM5_32002** | `es-vwap-orderflow-topstep-scalper` | Index-intraday-MR cluster cap from Orthogonal Return Sources Program 2026-08-13 (one build until probe-ticket `166696e5` correlation evidence lands; sibling of dispatched card `68333e26`). | `allocated` | Re-evaluate upon probe ticket `166696e5` completion. Do not draft/build ahead of probe evidence. |
| **QM5_32004** | `indices-overnight-gap-fill-continuation` | Index-intraday-MR cluster cap from Orthogonal Return Sources Program 2026-08-13 (one build until probe-ticket `166696e5` correlation evidence lands; sibling of dispatched card `68333e26`). | `allocated` | Re-evaluate upon probe ticket `166696e5` completion. Do not draft/build ahead of probe evidence. |

---

## 4. Category 3: Genuinely Missing Cards (0 IDs)

- **Count:** 0
- **Finding:** Every single one of the 100 cards from the Master Century Suite drop (`Strategy_Cards_Overview.md`) has a definitive disposition recorded in `decisions/2026-08-15_century_suite_intake_triage.md`.
- **Action:** No cards are required to be authored.

---

## 5. Verification & Consistency Check

1. `framework/registry/ea_id_registry.csv`:
   - 16 Rejected IDs are correctly marked `retired`.
   - 2 Deferred IDs are correctly marked `allocated`.
   - 82 Approved IDs are correctly marked `active`.
2. Total Century IDs accounted for: $16 + 2 + 82 = 100$.
3. Reservoir check: 82 approved Century cards reside in `strategy-seeds/cards/approved/` and `D:/QM/strategy_farm/artifacts/cards_approved/`.

---
*Signed by Gemini (Strategy Farm Orchestrator)*  
*Timestamp: 2026-08-17*
