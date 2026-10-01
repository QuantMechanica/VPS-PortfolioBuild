# QM5_41470 paired-book evidence: independent methodological critique

Task `f6d932f4-f8fd-40a4-ac30-a3e27a033379` · parent `53381214` · critic: Claude Opus (did not create the simulations, reconciliation or supplement) · 2026-10-02.

Scope: interpretation only. Inputs are the five packet files (sha256 verified against `input_manifest.json`, see `paired_check.json.packet_sha256`), plus `DESCRIPTIVE_SUPPLEMENT.md` and `descriptive_supplement.json` (sha `4c0f3d6b…` matches payload). No simulation, source fetch, DB edit or canonical change. The arithmetic comes from `paired_check.py`, a read-only script over `paired_rows.jsonl`, and its output is `paired_check.json`.

**Verdict: QUALIFIED_DIAGNOSTIC_SUPPORT / AUTHOR_NARRATIVE_REWORK.** In the persisted rows, the paired normal-arm marginal benefit of adding 41470 at .15625 is real and reproduces across the seeds. Several author statements round it up or mislabel it. Nothing here shows admissibility or progress toward the OWNER calendar/cash goal. I found no engine bug. Absence of proof is not proof of a bug.

## 1. Claim table

| # | Claim | Status | Supporting packet field / excerpt |
|---|---|---|---|
| 1 | Adding 41470 at .15625 (book risk 1.71875→1.875%) lowers normal point P80 by **−35.2 bd** (per-seed −37..−33) | SUPPORTED (paired diagnostic) | `paired_rows` normal.p80_bd; `deltas.D_41470_0.15625.normal.p80_bd` |
| 2 | Conservative LCB-crossing t80 moves **−44 bd** (−51..−36). Levels are 1053→1009 bd; point P80 is 996.6→961.4 bd | SUPPORTED. This is a different metric from point P80 and must be quoted separately | normal.t80_bd; `_payout_frontier` 941-969; `quantile_day` 477-482 |
| 3 | Author: normal ΔLCB "+0.01" at .15625 | OVERCLAIM (rounding). The mean is **+0.00528** (+0.0036..+0.0065). The 20k synthesis reported +0.00 | normal.lcb per seed |
| 4 | Author: stress ΔLCB "min ≥ +0.01 in every cell" | OVERCLAIM, CONFIRMED. At .15625 the range is **+0.0056..+0.0098** (mean +0.0078). At .3125 it is +0.0091..+0.0204 | stress.lcb per seed |
| 5 | ΔP_EVER "+0.01" | Rounded. The true value is +0.00664 (+0.0061..+0.0074) | normal.p_ever |
| 6 | Admission test (ΔP80<0 ∧ ΔLCB≥0) passes in normal, both weights, every seed | SUPPORTED as a per-seed fact. Min ΔLCB at .15625 = +0.0036 | per-seed deltas |
| 7 | Stress P80 undefined on both sides: P_EVER .7651–.7908 < .80, and quantile_day needs ≥⌈.8n⌉ successes | SUPPORTED within the model. "Structural" means within this cost/model, not beyond it | stress.p_ever; `governor_ladder.py:477-482` |
| 8 | Book window "2019-01-22..2025-11-21, 1,784 bd" | WRONG FOR THE SIMULATIONS. All 25 rows show **2019-02-06..2025-10-21, 1750 bd** (grid_bd 1750). 1784 bd is the outer prepared-stream window | `window`, `stats.grid_bd`; supplement §Window lineage |
| 9 | 20k→40k agreement shows the result is "not a Monte-Carlo artefact" | OVERREACH. It shows only MC repeatability. It is UNVERIFIED whether the 40k draws are independent of the 20k draws (same seed labels). It says nothing about market-history, model or selection uncertainty | author §0/§4; `_stage_index_matrix` 793-802 |
| 10 | Seeds are paired / common random numbers (CRN) | PLAUSIBLE, not end-to-end CONFIRMED. Support: (a) the RNG is `default_rng([seed, stage])`, independent of sleeve content; (b) all 25 rows share grid 1750 bd and n_paths 40000, and every key is `S` (stress=True → lightweight=False on all arms); (c) the paired-delta SD is below the level SD (P80 1.79 vs 5.81 bd; P_EVER .0005 vs .0011). Not excerpted: the `_bootstrap_index_matrix` body and the wiring that routes `_padded_to_fp` into the build. For LCB at .3125 the delta SD (.0030) exceeds the level SD (.0026), so batch-p05 LCB gets weaker variance reduction | `p80_levers.py:75-92,111-116`; `first_passage.py:793-802`; `crn_signature` |
| 11 | Seed means used as estimates | P_EVER: the arithmetic mean equals the pooled 200k share exactly (equal n). P80: the mean of five per-seed quantiles is not the pooled 200k quantile, so pooled P80 is NOT_MEASURED. LCB: the mean of five batch-p05 values is **not** a confidence bound for the pooled set or the mixed population, so pooled LCB is NOT_MEASURED | `_batch_ci` 818-847 |
| 12 | LCB as uncertainty | The LCB is a 90% batch interval over one block-bootstrap of one 2019–2025 history. It covers MC resampling only. Market-history, regime, cost-model and **selection** uncertainty are not covered: 41470 entered after Q08–Q11 on the same history, with 246 in-window trades | `_batch_ci` docstring; author §1 |
| 13 | IND arm "isolates timing-dependence vs pure quality" | OVERREACH. IND reuses the same 246 trades, with a **different shift per seed** (active_book_days 1635–1649). That is five shift draws, not a distribution. Observed result: the random shifts beat the actual timing (ΔP80 −43.4 vs −35.2; ΔLCB +.0087 vs +.0053). The benefit therefore cannot be credited to a favorable timing relation. IND also cannot separate quality from added risk. A risk-scaled incumbent control is NOT_MEASURED | `cmd_frontier` 561-565; IND rows |
| 14 | Δmax-loss −0.0010, Δdaily-loss 0 | SUPPORTED as **breach probabilities** (max-loss −.00098, range −.0012..−.0006). These are not drawdown USD. The supplement's realized balance max DD *rises* 6262.43→6273.57 USD (outer 1784-day window, pre-governor). Report both; do not call the change "drawdown reduction" | `max_loss_all`; supplement table |
| 15 | cond_p90_bd (867 vs 878) | Conditional on success only. Unconditional P90 is **not reached in any arm**: P_EVER max .8672 < .90. Account-level P90 is NOT_MEASURED/NOT_REACHED. `cond_p90` must never be quoted as P90 | `cond_p90_bd`; `_payout_frontier` 990-994 |
| 16 | "cd = bd×7/5" (−49.3 cd) | DIAGNOSTIC ONLY: 5/7 mapping, no dated calendar, no admin/bank lags | `time_contract` 1001-1012; reconciliation.limitations |
| 17 | SHADOW_BOOK action | Not admission. Canonical Shadow is still 9466. 41470 is a prospective addition at .15625, pending its missing governed Q12 prerequisite. The .3125 and IND arms are diagnostic, not admitted portfolios | reconciliation `candidate_disposition`; OWNER brief |

## 2. System state against the OWNER goal (P80 < 90 cd with payout-ever LCB ≥ .80)

- **Normal:** every arm has an LCB ≥ .80 in every seed, so P80 is finite. It is a **TARGET MISS by roughly 15×**: incumbent 988–1004 bd (~1383–1406 cd), candidate .15625 951–967 bd (~1331–1354 cd).
- **Stress:** **NOT_ACHIEVED for incumbent and candidate alike**. Every seed has LCB < .80 (incumbent mean .7505, candidate .7583). The relative improvement at .15625 is ΔLCB +.0078, ΔP_EVER +.0066, ΔP50 −12 bd, Δcensored −.0056. That closes about 16% of the incumbent's .0495 gap to .80 (ratio of point means, descriptive). No stress ΔP80 exists, and the failure is a property of the book, not of the candidate.
- Full calendar-to-first-positive-net-cash P80 remains **NOT_YET_ESTIMATED**. Costs: stress = 1.5× commission + 2 USD/lot. The financing swap substitution comes from narrative, and spread/slippage coverage is partial. Dependence: pair correlations run −.025..+.084, and the candidate/13213 tail ratio of 2.58 rests on **one** joint tail day. Low correlation is not independence.

**Demonstrated:** a small, seed-stable marginal diagnostic benefit at a specified weight, with the risk added. **Not demonstrated:** causal attribution to 41470's quality or timing, robustness outside the 2019–2025 history and model, admissibility (Q12), or any movement toward a P80 below 90 days.

## 3. Minimum corrective actions for parent 53381214 (in priority order, no new simulation)

1. **Correct the numbers.** Replace the rounded deltas in the author narrative with 4-dp means plus per-seed ranges from `paired_check.json`, especially stress ΔLCB min +.0056 and normal ΔLCB +.0053. Quote point-P80 Δ and t80 Δ separately, each with its levels.
2. **Correct the window.** State that the simulations use 2019-02-06..2025-10-21 / 1750 bd and label 1784 bd as the outer stream window, citing the supplement. Do not adopt either window as a new boundary rule.
3. **Relabel the statistics.** Seed means become "mean of 5 per-seed estimates (MC repeatability)". Pooled P80 and pooled LCB become NOT_MEASURED. Unconditional P90 becomes NOT_REACHED/NOT_MEASURED. Breach probabilities must stay distinct from drawdown USD.
4. **Withdraw two phrases.** Remove "not a Monte-Carlo artefact" and "isolates timing vs quality". Disclose the IND direction and the per-seed shift variation, the added risk, and the missing leverage control. A risk-scaled control is only needed if a causal claim is wanted; the qualified book claim does not need one.
5. **Settle CRN cheaply (optional).** Add the `_bootstrap_index_matrix` body and the `_padded_to_fp` wiring excerpt from the hashed sources. That would let CRN be marked CONFIRMED without a rerun.
6. **Keep the status unchanged.** The incumbent D2g6 stays frozen, canonical Shadow stays 9466, and 41470 stays prospective at .15625 pending Q12. Confirm that any SHADOW_BOOK text in `FTMO_BOOK_CURRENT.md` carries this qualification (UNVERIFIED from this packet).

This critique confirms ASTRA's arithmetic corrections in `compact_20260927/ACCEPTANCE.md` independently. Every corrected range there matches `paired_check.json`.
