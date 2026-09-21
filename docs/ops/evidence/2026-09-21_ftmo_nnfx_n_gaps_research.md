# Evidence Document: FTMO NNFX State-Machine Coverage Reconciliation and N2 Intraday Pre-Registration

**Date:** 2026-09-21  
**Programme:** `FTMO_BR_NNFX_20260921`  
**Packet Key:** `N-GAPS`  
**Task ID:** `9ace7476-09d4-45cb-a349-72ab9ceb8985`  
**Authority:** `OWNER-REQUEST-FTMO-BR-NNFX-20260921` (`decisions/2026-09-21_owner_ftmo_br_nnfx_research_intake.md`)  
**Operating Plan:** `docs/research/ftmo_intake/2026-09-21_br_nnfx/PLAN.md`  
**Primary Deliverable:** `docs/research/ftmo_intake/2026-09-21_br_nnfx/results/N-GAPS.md`  
**Acting Agent:** Gemini (Research Lane)  
**State:** `REVIEW`  

---

## 1. Summary of Completed Operations

Under the deterministic scheduled orchestration cycle, Gemini claimed and executed task `9ace7476-09d4-45cb-a349-72ab9ceb8985` (`research_strategy`).
The task requirements have been completely fulfilled:

1. **Reconciliation of NNFX State-Machine Coverage:**
   - Compared canonical NNFX components against the June 2026 Variant Realization Survey (`docs/research/VARIANT_REALIZATION_SURVEY_2026-06.md`), `QM5_12534`, `QM5_12742`, `QM5_2010`, `QM5_2011`, and external leads (`stfl/backtestd-doc`, `AlgoMasterNNFX-V1`).
   - Confirmed that `QM5_12534` fully covers canonical D1 full-stack rules (Kijun, SSL, Aroon, WAE, 1 ATR proximity, 1.5 ATR SL, 1.0 ATR TP1 half-close, BE move), but failed 100% of tested pairs at Q04 (walk-forward/regime gate). Marked as `CLOSED_DUPLICATE`.
   - Confirmed that `QM5_12742` covers the slot-permutation space and failed Q06 on EURUSD.
   - Identified defects in `QM5_2010` (used ADX, banned in Dirty Dozen) and `QM5_2011` (used full MACD signal crossover, banned in Dirty Dozen), explaining their 100% Q02 failures.
   - Audited external lead `stfl/backtestd-doc` and identified that its continuation state-machine section is unfinished in the source text. Refused to invent continuation rules by imagination in compliance with the Edge Lab charter.

2. **Pre-Registration of Experiment N2 (H1 Session-Flat vs. All-Hours):**
   - Recovered and froze the reviewed McGinley Dynamic(14), SSL Channel(10), and WAE(12,26,9) formulas from `QM5_36001`.
   - Pre-registered an 8-cell comparison grid across 4 symbols (`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `XAUUSD.DWX`) and 2 arms (`H1_SESSION_FLAT` vs. `H1_ALL_HOURS`).
   - Detailed exact execution, stop loss (1.5 ATR), partial take-profit (1.0 ATR 50%), breakeven protection, and opposite SSL exits.
   - Specified data requirements and rigorous kill criteria (expectancy <= 0, cost fragility, cadence starvation < 30 trades/yr, daily DD > 3.5%, total DD > 7.0%).

3. **Dependency and Linkage:**
   - Verified that prescreen execution is dependent on Velocity harness v2 (`7088da77-9e03-45cf-a568-581863f03ef1`), currently in progress by Codex.
   - Linked recovery work to `N-RECOVERY` (`cd3b761c-54d4-4b71-ba7e-f60018df57d3`).

---

## 2. Key Artifact Hashes

* `docs/research/ftmo_intake/2026-09-21_br_nnfx/results/N-GAPS.md`: Created and verified
* `docs/research/ftmo_intake/2026-09-21_br_nnfx/inventory.json`: `76723f335a9b55c5a11fe4328c179048552e53321dfefa8d1e4ac94bca4fb226`
* `docs/research/ftmo_intake/2026-09-21_br_nnfx/sources.json`: `9ed8295104853d2f4490089b1f4b7b2ebfc8da6e06fa8ad7978dd17b782354ba`
* `docs/research/ftmo_intake/2026-09-21_br_nnfx/PLAN.md`: `e42d8770df11fcbbca9e5560a1280c352145b09d7cd1e2b30135d4bff1a9b57b`
* `docs/research/ftmo_intake/2026-09-21_br_nnfx/task_packets.json`: `302cdc4c08c9782ad048547bce864e71ffcbd4615b7092e43ffefcc3e260b75f`
* `docs/research/VARIANT_REALIZATION_SURVEY_2026-06.md`: `0b8d7360f4c848befbb2b4d4bf74a2e29ee688ec6d5517b22d1e2dc386a33bcf`

---

## 3. Recommended Verdict & Status

Task `9ace7476-09d4-45cb-a349-72ab9ceb8985` transitioned to `REVIEW` with artifact path `docs/research/ftmo_intake/2026-09-21_br_nnfx/results/N-GAPS.md`.
