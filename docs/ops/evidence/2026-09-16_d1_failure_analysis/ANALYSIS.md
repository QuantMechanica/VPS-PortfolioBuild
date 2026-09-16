# D1 V3 Q08 Cohort — Failure-Concentration Analysis

- Date: 2026-09-16
- Task: `d1-failure-analysis` (OWNER directive §12: learn from failure concentration; do NOT loosen Q08)
- Preflight: `agent_worktree_preflight.py` PASS (branch `agents/board-advisor`, no collisions)
- Population: 16 fresh V3 Q08 rows (repair enqueue `2026-09-16_q08_amend_v3`, batches 1+2), all window `2017.01.01–2025.12.31`.
  EA ids: 1159, 10804, 10661, 10211, 12958, 9123, 10291, 10267 (batch 1), 10287, 9576, 1230, 9973, 13012, 11882, 10269, 10280 (batch 2).
- Executed at analysis time: **13** (snapshot in the task brief said 12; 11882 finished during analysis).
  Verdicts: **11× FAIL_HARD, 1× FAIL_SOFT (9973), 1× INVALID (10211)**. Remaining 3: 10269 (active), 10280 (pending), 13012 (pending).

Sources: `D:\QM\reports\work_items\<wi>\QM5_<ea>\Q08\<sym>\aggregate.json` + `8_*.json` sub-gate files
+ `q08_sealed_stream.*.jsonl`; work-item payloads in `D:\QM\strategy_farm\state\farm_state.sqlite`;
setfiles under `framework/EAs/<ea_dir>/sets/`; gate code `framework/scripts/q08_davey/`,
`framework/scripts/q08_5_neighborhood_runner.py`.

## 1. Per-row failure-mode extraction

All sub-gate values verbatim from each row's aggregate.json / 8_*.json. "Hard causes" are the
aggregate's `dl082_ext_option_d_detail.hard_causes` — the sub-checks that actually produced FAIL_HARD.
DSR window = full 2017.01.01–2025.12.31 (3,287 calendar days; DSR_V2, effective_trial_count=1,
selection_correction not applied — see §3). §8.5/§8.7 = neighborhood/PBO (window 2018.07.02–2025.12.31
where they ran). §8.10 regimes are ATR terciles low/normal/high plus named crisis windows
(COVID_2020, UKRAINE_2022, INFLATION_2022).

| EA | Family | Sym | Verdict | Hard cause(s) | §8.2 DSR p (thr 0.05) | Sharpe ann / net | Trades | §8.5 | §8.7 PBO | §8.10 regime | §8.4 losing months | Other flags |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1159 | qp overnight-MA20 trend (D1) | NDX | FAIL_HARD | 8.2 | 0.326 | 0.15 / +8.6% | 923 | INVALID¹ | INVALID | low,high unprofitable; INFLATION_2022 −11,067 | 1,4,8,9,10,11,12 | 8.6 pf-after-top5% 0.77 |
| 10267 | gawd SMA25 trend (D1) | NDX | FAIL_HARD | 8.2, 8.9, cost_cushion, portfolio_net_pf | 1.000 | −2.06 / −22.6% | 57 | INVALID¹ | INVALID | all 3 unprofitable; all crisis windows negative | all 12 | 8.6 0.00; 8.9 top20% months = 100% |
| 10287 | cinar Ichimoku trend (D1) | NDX | FAIL_HARD | 8.2 | 0.145 | 0.35 / +11.2% | 235 | INVALID¹ | INVALID | high unprofitable | 2,8,9,10,11 | 8.6 0.91; 8.11 MC-DD ratio 2.33 |
| 10291 | cinar Alligator trend (D1) | NDX | FAIL_HARD | 8.2 | 0.152 | 0.34 / +13.9% | 416 | INVALID¹ | INVALID | high unprofitable | 4,8,9,10,11,12 | 8.6 0.85 |
| 10661 | tv SMC order-block (H1) | GDAXI | FAIL_HARD | 8.2 | 0.089 | 0.42 / +12.3% | 78 | INVALID¹ | INVALID | low unprofitable | 2,3,4,7,11,12 | — |
| 10804 | tv Supertrend long (H1) | GDAXI | FAIL_HARD | 8.2 | 0.323 | 0.15 / +10.6% | 588 | PASS 4/4 plateau | PASS | all regimes profitable; INFLATION_2022 −7,888 | 6,8,9,10,11 | 8.6 0.63; 8.11 MC-DD ratio 2.12 |
| 11882 | Connors double-7 MR (D1) | NDX | FAIL_HARD² | 8.2 | 0.326 | 0.15 / +3.8% | 168 | PASS | 54.3% (soft) | low,high unprofitable | 1,2,9,10 | 8.6 0.86 |
| 1230 | carver dynvol-MAV trend (D1) | NDX | FAIL_HARD | 8.2, 8.9 | 0.116 | 0.39 / +2.9% | 110 | INVALID¹ | INVALID | high unprofitable | 4,8,9,11 | 8.6 0.99; 8.9 runs p=0.037 |
| 12958 | NNFX HMA-WAE swing (D1) | GDAXI | FAIL_HARD | 8.2 | 0.172 | 0.32 / +7.7% | 291 | PASS | 45.7% (soft) | all regimes profitable | 1,2,5,7,9 | 8.6 0.89 |
| 9123 | aa TES-01325 cross trend (D1) | NDX | FAIL_HARD | 8.2, 8.8, cost_cushion, portfolio_net_pf | 1.000 | −2.37 / −39.2% | 71 | INVALID¹ | INVALID | all 3 unprofitable | all 12 | 8.8 decay 100%; 8.6 0.00 |
| 9576 | bandy z-score MR (D1) | NDX | FAIL_HARD | 8.2 | 0.295 | 0.18 / +1.7% | 50 | PASS | 68.6% FAIL | informational (0 trades in low regime) | 1,2,3,7,8 | 8.6 0.92 |
| 9973 | bandy IBS-extreme MR (D1) | NDX | FAIL_SOFT | none hard | 0.025 PASS | 0.69 / +9.2% | 162 | PASS | 85.7% FAIL | all regimes profitable | 1,2,9 | — |
| 10211 | tv Williams-%R MR (D1) | NDX | INVALID³ | n/a (INVALID) | 0.010 PASS | 0.69 / +11.7% | 74 | INVALID¹ (decisive) | INVALID | join failed (0 classified) | 2,6 | — |

¹ `neighborhood_evidence_lineage_invalid:baseline_setfile_defect:empty_strategy_params` — see §3.
² Finished 2026-09-16T13:09Z, after the task brief's 12-executed snapshot.
³ Verdict INVALID is decided by the §8.5 lineage defect, not by economics; its §8.2 DSR *passed* (p=0.010).

## 2. Concentration analysis

### 2.1 Same economic weakness? — YES, one universal cause
**§8.2 DSR MC FDR is a hard cause in all 11 FAIL_HARD rows** (p = 0.089 … 1.000, threshold 0.05).
It is the *only* hard cause in 8 of 11. The discrimination is clean:
the two rows with daily Sharpe ≈ 0.036 (ann. 0.69) — 9973 and 10211 — are exactly the two rows
that pass §8.2 (p = 0.025 / 0.010), and they are the only two rows that are not FAIL_HARD.
Every FAIL_HARD row has ann. Sharpe ≤ 0.42 (two are net-negative over the full window: 10267 −22.6%, 9123 −39.2%).
Over 3,287 calendar days with 50–923 trades, these Sharpe ratios are statistically indistinguishable
from zero. **The DSR gate is not being harsh via multiplicity deflation**: effective_trial_count=1,
`selection_correction_applied=false` (DECLARED_SINGLE_CONFIGURATION) in every row examined — the rows
fail on raw Sharpe ≈ 0 alone (e.g. 1159: z=0.45).

Secondary concentrations (all economic, none decisive alone):
- **§8.10 regime/crisis**: 8 of 13 rows have ≥1 unprofitable ATR regime; the *high-vol* regime is
  unprofitable in 6 rows (5 NDX + 9123 all-regime). Crisis windows: INFLATION_2022 negative in 8 of 13
  (up to −11,067 on 1159); UKRAINE_2022 negative in 7 of 13.
- **§8.4 seasonal**: all 13 rows fail; months 8–11 (Aug–Nov) recur as losing months in 9 of 13 —
  a consistent autumn weakness for index longs.
- **§8.6 chopping block**: pf_after_top5pct_removal < 1.0 in 9 of 12 scored rows — edge concentrated
  in the top 5% of trades.
- **§8.11 MC shuffle DD**: realized DD below MC p95 for 10287 (ratio 2.33) and 10804 (2.12) — risk
  underestimation on top of weak edge.

### 2.2 Same strategy family? — trend-following dominates the corpses
Families (from EA dirs): trend/MA-breakout — 1159, 10267, 10269*, 10287, 10291, 9123, 1230, 10804,
10661 (9 of 16); mean-reversion — 9576, 9973, 11882, 10211, 10280*, 13012* (*not yet executed).
Every executed trend row FAIL_HARDs on §8.2. The mean-reversion rows produce the only non-hard
outcomes (9973 FAIL_SOFT, 10211 INVALID) plus one DSR fail (11882). Read: **D1/H1 index
trend-following on NDX/GDAXI 2017–2025 has no measurable risk-adjusted edge**; the MR cohort is
marginal (one pass-quality row, one artifact exclusion).

### 2.3 Same regime/window? — same window by design; failure is window-internal
All rows share the 2017–2025 window and same-day gate calibration (2026-09-16), so "same window"
is provenance, not surprise. The informative concentration is inside the window: high-vol regime
and INFLATION_2022/UKRAINE_2022 crisis sub-windows carry the losses (§2.1). The two GDAXI rows
with full evidence (10804, 12958) were profitable in all three ATR regimes yet still FAIL_HARD on
DSR — regime-balanced P&L with ~0.15–0.32 ann. Sharpe is still not an edge.

### 2.4 Symbol-specific? — no survival difference
NDX: 11 rows → 8 FAIL_HARD, 1 FAIL_SOFT, 1 INVALID (1 running). GDAXI: 5 rows → 3 FAIL_HARD
(2 with complete evidence), 2 pending. Failures and failure mode (§8.2) are identical on both
symbols; the GDAXI H1 rows trade more (291–588 trades) and still fail DSR. Not symbol-specific.

### 2.5 Parameter instability (§8.5)? — NOT the failure mode
Where §8.5 ran (10804, 11882, 12958, 9576, 9973), it PASSED in all 5 (full ±10% plateau).
§8.7 PBO is elevated wherever computable (45.7%, 54.3%, 68.6%, 85.7% vs 40% max) — the surviving
candidates sit on wide plateaus but were still selected from an overfit-rich neighborhood, and
their plateau-robustness cannot rescue a zero-Sharpe baseline. Failure is **edge absence**, not
parameter fragility.

## 3. Artifact-bias test — does a shared non-economic defect manufacture FAIL_HARD?

**The defect is real.** 8 of 13 executed rows carry `empty_strategy_params` setfiles on their target
symbol (`; strategy-specific params` block ends in `; card_defaults_source=not_found`, zero
`strategy_*` rows): 10211, 10267, 10287, 10291, 10661, 1159, 1230, 9123 (and pending 10280).
The §8.5 runner (`q08_5_neighborhood_runner.py:inspect_baseline_setfile`) raises
`ValueError('baseline setfile has no strategy parameters')` → §8.5 INVALID → §8.7 PBO INVALID
(`insufficient_distinct_configs:got=0`). The aggregate's baseline-setfile guesser
(`q08_davey/aggregate.py:_guess_baseline_setfile`) matches any `*_backtest.set` excluding
stress/seed/perturb — **it does not exclude `ablation_` files**, which is why 10804 (whose target
setfile is also EMPTY) got lucky: the glob returned its `..._GDAXI.DWX_H1_backtest_ablation_00.set`
(7 params) and §8.5 ran. The other 7 defect rows have no ablation setfile at all. This is the same
defect family documented in `tools/strategy_farm/backfill_setfile_strategy_params.py` and
`docs/ops/evidence/2026-09-05_q08_empty_strategy_params_11179.md` — the V3 repair enqueue did not
backfill strategy params before requeueing.

**But the defect did not bias the cohort toward FAIL_HARD.** Discriminating evidence:
1. `hard_causes` never contains 8.5 or 8.7 in any row. §8.7 INVALID appears only as the reason code
   `DL082_EXT_8_7_NOT_PASS_OR_EDGE_SOFT:INVALID`, which blocks DL082-ext-option-D credit, never adds
   a hard cause. Every FAIL_HARD is decided by §8.2 (and economic companions), which is computed from
   the realized trade stream — independent of setfile params.
2. The 5 rows with complete neighborhood evidence fail identically: 10804 (§8.5 PASS, §8.7 PASS)
   FAIL_HARD on §8.2 alone; 12958, 11882, 9576 same; 9973 is the cohort's only FAIL_SOFT. Verdict
   mix with §8.5 INVALID: 7 FH + 1 INVALID; without: 4 FH + 1 FS. No bias (the INVALID is 10211,
   decided *by* the defect, not toward FAIL_HARD).
3. Counterfactual on the calibration: `DL082_EXT_OPTION_D_REQUIRED.8.2 = [PASS]` — ext-option-D can
   never rescue an §8.2 EDGE_HARD, so even perfect §8.5/§8.7 evidence could not flip any of the 11
   FAIL_HARDs. The defect's only verdict-level effect is **exclusion**: 10211 (DSR p=0.010, the
   cohort's best economics) was denied a merit verdict entirely. That is a real cost — it likely
   removes a viable Williams-%R MR candidate from the book — but it biases toward *no verdict*,
   not toward FAIL_HARD.
4. No other shared artifact cause: baseline runs all PASS with sane trade counts; window edges,
   engine version (q08_neighborhood_param_type_aware_v2), gate calibration, and repair provenance
   (SUPERSEDED_REPAIR dispositions, both batches) are identical across verdicts — batch-1 vs
   batch-2 failure rates are indistinguishable.

**Verdict: economic filter, not artifact bias.** Q08 is correctly filtering strategies with
statistically-zero Sharpe on 9-year NDX/GDAXI D1/H1. The setfile defect is a parallel,
must-fix admission bug (it suppresses stability evidence and voided 10211) — fixing it changes
evidence completeness, not the FAIL_HARD concentration.

## 4. Prioritization

(see `PRIORITIZATION_NOTE.md` in this directory for the standalone note + agent-34 cross-reference)

1. **Remaining rows**: 10269 (gawd-wma30 trend — same family as 10267 which went −22.6% net; expect
   FAIL_HARD on §8.2, its setfile has 5 params so evidence will be complete), 13012 (grimes-complex-pb
   MR, 12 params, evidence will run), 10280 (**EMPTY setfile → §8.5/§8.7 will INVALID again**; backfill
   before or accept another INVALID). Do not requeue any FAIL_HARD row on the setfile defect — the
   defect is not what failed them.
2. **Agent-34 Q08 DSR remainder cohort**: see `CROSSREF_agent34_q08_dsr_remainder.md` — apply the
   same two-axis test (hard causes vs §8.5 evidence availability); expect DSR to dominate there too.
3. **Fix the admission lint, not the gate**: add a pre-enqueue check "target setfile has ≥1
   `strategy_*` param (or an ablation fallback)" so `empty_strategy_params` INVALIDs stop recurring;
   optionally exclude `ablation_*` from `_guess_baseline_setfile` or make it deterministic.
4. **Future NDX/GDAXI admission**: treat ann. Sharpe < ~0.5 on the 9-year D1 window as a pre-screen
   failure (it is an automatic §8.2 DSR fail at these trade counts); weight MR families over
   trend/MA families for index sleeves; require non-negative INFLATION_2022 crisis-window P&L or a
   documented hedge; treat high-PBO (>50%) plateaus as a soft demerit even when §8.5 passes.
5. **Do not loosen Q08**: the 11 FAIL_HARDs are economically correct rejections; the one row the gate
   "lost" (10211) was lost to the setfile defect, which is fixable without touching gate calibration.
