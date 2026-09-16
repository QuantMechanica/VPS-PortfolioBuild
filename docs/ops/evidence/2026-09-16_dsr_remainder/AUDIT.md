# AUDIT — Q08 DSR-context blocked remainder (2026-09-16)

**Auditor:** Kimi (interim OWNER delegation), branch `agents/board-advisor`.
**Preflight:** `agent_worktree_preflight.py --task-id dsr-audit` PASS (base `fa50b991…`).
**DB access:** read-only (`file:…farm_state.sqlite?mode=ro`). No DB writes. No execution of any repair.

## 1. Population reconciliation (77 → 39)

Task definition: `work_item_holds.hold_code LIKE 'Q08_DSR%'` unreleased **+** Q08 `pending`
rows failing `dsr_cohort.claimability_precheck`.

| set | rows |
|---|---|
| unreleased `Q08_DSR%` holds (active=1, released_at IS NULL) | 48 |
| Q08 pending failing `claimability_precheck` | 76 |
| union | **77** |
| minus: failing at `SINGLE_CONFIGURATION_UNAVAILABLE:BUILD_IDENTITY_MISMATCH:*` | −38 |
| **= reconciliation DSR_CONTEXT bucket (12:37Z snapshot: 39)** | **39** |

The 38 excluded rows are **all superseded residue** (verified against
`work_item_supersedes`): 16 = V3/D1 cohort originals (dispositioned 09-16,
fresh-enqueued under `OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916`/D1) + 22 = V2-era
duplicates (`OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914` dispositions of 1328×6, 13137,
11263, 1910, 10290, 12350, 11121, 41394, 9579 ×2 each). The precheck does not consult
supersede edges, so they surface as `BUILD_IDENTITY_MISMATCH:mq5`; the reconciliation's
reason-token mapping (`factory_population._bucket_from_precheck_reason`,
`tools/strategy_farm/factory_population.py:177-183`) routes them to `BUILD_IDENTITY_BLOCKED`,
not DSR_CONTEXT. They need **no repair** — at most stale-hold cleanup under a later
housekeeping decision. They are out of scope for D6.

Live classifier re-run (`.scratch/dsr_remainder_classify_0916.py`, output
`classification_live.json`): Q08 pending+active = 91 → ACTIVE 2 · CLEAN_CLAIMABLE 3 ·
DSR_CONTEXT 19 · GOVERNANCE(precheck-declaration) 20 · BUILD_IDENTITY 38 · OTHER_HOLD 9.
The 39 = 20 declaration-missing + 19 DSR_CONTEXT-bucket rows, exactly.

## 2. Class counts

| class | meaning | rows |
|---|---|---|
| **A** | SAME_V3_CLASS — identical defect to the approved 16-card V3 cohort (approved card lacks the `qm-dsr-single-configuration` declaration **and** the row carries no build identity; repair = amend + disposition + fresh enqueue) | **12** |
| **B** | DIFFERENT_TECHNICAL_DEFECT | **24** |
| **C** | GENUINELY_MISSING_EVIDENCE (sealed-stream window gaps etc.) | **0** |
| **D** | OWNER_SEMANTIC_BOUNDARY | **3** |

A-class dominates the repair-relevant population (12 of 15 rows needing a repair
decision; the other 27 are non-V3-pattern defects, residue, or semantic calls).

### Subclasses (B)

| subclass | rows | count |
|---|---|---|
| B5 candidate window never stamped (enqueue-time defect; Q07 predecessors carry no window either, so re-enqueue needs explicit `--from-date/--to-date`) | 10848, 11132, 9573, 12712(a17469d0), 12778, 12864, 13059, 13076 | 8 |
| B3 no approved card at all (sweep-arm 4147x rows; V2 class B, sweep-arm decision `OWNER-DEC-Q08-SWEEP-ARM-CONTEXT-20260914` Weg-2 recommendation outstanding) | 41470, 41472, 41473, 41474 | 4 |
| B1 censused EA — `no_optimization_search` declaration would be false; claim-time factory-search ledger (`dsr_cohort._factory_search_before_q08_claim`, EA-wide per `dsr_cohort.py:283-287`) would refuse | 10145/GDAXI, 10145/NDX (7 prior Q12/Q14 rows), 10692/GDAXI (2 prior Q14 rows) | 3 |
| B4 multi-symbol card disposition (card already declares a different symbol; one declaration per card, `dsr_single_configuration.declaration` `len(blocks)==1`) | 12350/NDX (card=XAUUSD.D1), 10287/XAUUSD (card=NDX.D1, V3 batch-2 card), 1230/AUDJPY (card=NDX.D1) | 3 |
| B2 SPEC.md missing — amend tool fails closed (`missing ['spec']`) | 12361, 12484, 1551 | 3 |
| B7 superseded residue with stale unreleased Q08_DSR holds (no repair; hold cleanup only) | 12712(b1bd1d06), 12712(b68d05cd) | 2 |
| B6 declaration drift — card `locked_parameters` stale vs current mq5/setfile (`LOCKED_PARAMETER_DRIFT`); row also superseded | 11167 | 1 |

### Subclasses (D)

| subclass | rows | count |
|---|---|---|
| D1 ablation-set EA — a `no_optimization_search: true` declaration would be a false statement (V2 explicitly excluded 10163/10932; sweep-arm execution doc: "stay INVALID, never a single-configuration declaration"); needs the Weg-2 (retire standalone Q08 vs Q13/Q14-head-to-head-only) call | 10932/XAUUSD (ablation_02), 10163/GDAXI (ablation_04) | 2 |
| D2 poison-pill quarantine disposition — DSR defect **already repaired** under V2 (precheck CLEAN, card declares USDCAD/H4, identity Y); independently quarantined 2026-09-14T15:36:26Z, 13 consecutive `phase_runner_invalid_report` failures, 0 successes ever (`poison_pill_quarantine` row, active=1). Releasing the DSR hold alone does not unblock. | 1328/USDCAD | 1 |

## 3. Per-row table (39 rows)

Identity Y/N = any of mq5/ex5/setfile sha256 present (row column or payload
`artifact_identity`/`expected_*`). "—" = not applicable.

| row id | EA | symbol | hold (unreleased) | precheck reason | card / decl | identity | class · subclass | evidence |
|---|---|---|---|---|---|---|---|---|
| f762cbe6… | QM5_10037 | XAUUSD.DWX | Q08_DSR_CONTEXT_UNAVAILABLE | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **A** | card lacks `qm-dsr-single-configuration` block; row sha256 NULL; EA search-clean (0 opt rows); Q07 0bd38739 done/PASS; window 2017–2025 present |
| 75af8ef0… | QM5_10122 | XAUUSD.DWX | Q08_DSR_CONTEXT_UNAVAILABLE | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **A** | same pattern; Q07 d93be636 done/PASS 09-14 |
| fba34963… | QM5_10127 | NDX.DWX | Q08_DSR_CONTEXT_UNAVAILABLE | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **A** | Q07 bd1534b2 done/PASS 09-14 |
| 4300c5ad… | QM5_10134 | XAUUSD.DWX | Q08_DSR_CONTEXT_UNAVAILABLE | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **A** | Q07 e48b7bfe done/PASS 09-14 |
| c297063b… | QM5_10691 | NDX.DWX | Q08_DSR_CONTEXT_UNAVAILABLE | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **A** | Q07 cf197dd4 done/PASS 09-14; EA search-clean |
| 47bea32e… | QM5_10947 | NDX.DWX | RAM_RESERVATION_44GB_NOT_WINNABLE_20260914 **+** (Q08_DSR released) | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **A** (+independent RAM blocker) | Q07 49b48658 done/PASS 09-14; after V4 repair still needs the 44 GB RAM release (D3-class) |
| fda2f049… | QM5_1206 | SP500.DWX | RAM_RESERVATION_44GB_NOT_WINNABLE_20260914 | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **A** (+independent RAM blocker) | window = bare years 2018/2022 (year-edge resolution live since 09-14, `dsr_cohort._year_edge_text`); Q07 c66474ef done/PASS |
| ba75c59a… | QM5_12354 | NDX.DWX | Q08_DSR_CONTEXT_UNAVAILABLE | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **A** | Q07 d374a221 done/PASS |
| 676b23b9… | QM5_12358 | XAUUSD.DWX | Q08_DSR_CONTEXT_UNAVAILABLE | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **A** | Q07 e4be5458 done/PASS 09-14 |
| 4aa9b74b… | QM5_12366 | XAUUSD.DWX | Q08_DSR_CONTEXT_UNAVAILABLE | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **A** | Q07 67d04308 done/PASS 09-14 |
| 962d1a67… | QM5_12549 | XAUUSD.DWX | Q08_DSR_CONTEXT_UNAVAILABLE | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **A** | Q07 6fbc8bde done/PASS 09-14 |
| 235bf9ad… | QM5_1615 | XAUUSD.DWX | Q08_DSR_CONTEXT_UNAVAILABLE | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **A** | Q07 0b76d4ca done/PASS 09-14 |
| 601a9fa9… | QM5_10145 | GDAXI.DWX | Q08_DSR_CONTEXT_UNAVAILABLE | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **B · B1** | EA censused: 7 prior Q12/Q14 rows (latest Q12 2026-09-15); EA-wide factory-search refusal would fire at claim time (`FACTORY_SEARCH_LEDGER_PRECEDES_Q08`); needs grouped-cohort-per-symbol or retire (same disposition as the 09-16 10145/NDX analysis) |
| bdba95f1… | QM5_10145 | NDX.DWX | — (Q08_DSR never held; parked by precheck) | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **B · B1** | censused EA (same 7 rows); 09-16 verification doc already dispositioned this row as "NOT amendable" |
| 443ad2eb… | QM5_10692 | GDAXI.DWX | Q08_DSR_CONTEXT_UNAVAILABLE | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **B · B1** | EA censused: 2 prior Q14 rows (2026-08-13) — same claim-time refusal; not caught by the 09-16 21-row analysis (this row is outside the 21) |
| 2276786b… | QM5_12361 | NDX.DWX | — | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **B · B2** | `SPEC.md` absent in EA dir (live re-check 13:3xZ); amend tool fails closed `missing ['spec']`; Q07 e799d79e done/PASS 09-15 — joins V4 scope once SPEC exists |
| dfb2f622… | QM5_12484 | NDX.DWX | — | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **B · B2** | SPEC.md absent; Q07 29305fbf done/PASS 09-15 |
| 3b320089… | QM5_1551 | NDX.DWX | — | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **B · B2** | SPEC.md absent; Q07 b2481d6d done/PASS 09-15 |
| ce8f0416… | QM5_10932 | XAUUSD.DWX | Q08_DSR_CONTEXT_UNAVAILABLE (09-14 park) | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **D · D1** | row locks `…_ablation_02.set` — an ablation series is a research search; `no_optimization_search: true` would be false (V2 exclusion, receipt `3415f6c0`); sweep-arm doc: no sealed ledger in `ablate.py` → "stay INVALID, never a single-configuration declaration"; needs Weg-2 retire-vs-Q13/Q14 call |
| 2d3da3de… | QM5_10163 | GDAXI.DWX | RAM_RESERVATION_44GB_NOT_WINNABLE_20260914 | EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED | APPROVED / none | N | **D · D1** | locks `…_ablation_04.set`; same false-declaration class as 10932 (V2-excluded pair); SPEC.md now present; also RAM-held |
| 0031f42d… | QM5_12350 | NDX.DWX | — | SINGLE_CONFIG_CANDIDATE_MISMATCH | APPROVED / **XAUUSD.DWX/D1** | N | **B · B4** | card (V2-amended 09-14) declares XAUUSD.D1; one declaration per card; the NDX configuration cannot be declared on the same card — second-card vs retire disposition (09-16 verification doc item) |
| 5901ae3b… | QM5_10287 | XAUUSD.DWX | MONITOR_BUDGET_REVIEW_REQUIRED (Q08_DSR released) | CANDIDATE_WINDOW_UNAVAILABLE | APPROVED / **NDX.DWX/D1** (V3 batch-2 card) | Y | **B · B4** | multi-symbol mirror of the 12350 case: card now declares NDX/D1 (V3), this row is XAUUSD with no window; also monitor-budget-held; V3 fresh row e1c0d6c1 (NDX) owns the card's declared configuration |
| 63d4ce1d… | QM5_1230 | AUDJPY.DWX | Q08_DSR_CANDIDATE_WINDOW_UNAVAILABLE (09-14 park) | CANDIDATE_WINDOW_UNAVAILABLE | APPROVED / **NDX.DWX/D1** (V3 card) | N | **B · B4** | card declares NDX/D1 (V3); row is AUDJPY, windowless, identity NULL; V3 fresh row db1da509 (NDX) is live — AUDJPY needs its own disposition |
| c8d8c2c7… | QM5_10848 | GDAXI.DWX | Q08_DSR_CONTEXT_UNAVAILABLE | CANDIDATE_WINDOW_UNAVAILABLE | APPROVED / none | Y | **B · B5** | no window anywhere (row + payload + lineage); Q07 923997c7 done/PASS but windowless too; re-enqueue needs explicit dates; **also declaration-missing → promotes into V4 scope once windowed** |
| 169d5dda… | QM5_11132 | NDX.DWX | Q08_DSR_CONTEXT_UNAVAILABLE | CANDIDATE_WINDOW_UNAVAILABLE | APPROVED / none | Y | **B · B5** | same; Q07 9275f769 done/PASS; declaration also missing → V4-scope after windowing |
| 7aaf7760… | QM5_9573 | NDX.DWX | Q08_DSR_CONTEXT_UNAVAILABLE | CANDIDATE_WINDOW_UNAVAILABLE | APPROVED / none | Y | **B · B5** | same; Q07 0598961b done/PASS; declaration also missing → V4-scope after windowing |
| a17469d0… | QM5_12712 | QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1 | Q08_DSR_CONTEXT_UNAVAILABLE | CANDIDATE_WINDOW_UNAVAILABLE | APPROVED / **same symbol/D1** (V2 card) | Y | **B · B5** | V2-era fresh row: declaration + identity present, only the window is missing; Q07 1b9fa7a5 done/PASS (windowless); synthetic-symbol data coverage for the chosen window must be verified before re-enqueue |
| 30297fe9… | QM5_12778 | QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1 | OWNER_D5_BASKET_LEASE_HOLD | CANDIDATE_WINDOW_UNAVAILABLE | APPROVED / none | N (ex5 only) | **B · B5** | windowless; declaration also missing → V4-scope after windowing; independently D5-lease-held (custom-history lease) |
| 3d886f4b… | QM5_12864 | QM5_12864_XTI_XAG_RSPREAD_D1 | OWNER_D5_BASKET_LEASE_HOLD | CANDIDATE_WINDOW_UNAVAILABLE | APPROVED / none | N (ex5 only) | **B · B5** | same shape as 12778; D5-lease-held |
| cc2be960… | QM5_13059 | QM5_13059_XTI_AUDJPY_RSPREAD_D1 | OWNER_D5_BASKET_LEASE_HOLD | CANDIDATE_WINDOW_UNAVAILABLE | APPROVED / none | N (ex5 only) | **B · B5** | same; D5-lease-held |
| 1f1920cb… | QM5_13076 | QM5_13076_XTI_NZDCAD_RSPREAD_D1 | OWNER_D5_BASKET_LEASE_HOLD | CANDIDATE_WINDOW_UNAVAILABLE | APPROVED / none | N (ex5 only) | **B · B5** | same; D5-lease-held |
| bc7d5af7… | QM5_41470 | USDJPY.DWX | Q08_DSR_CONTEXT_UNAVAILABLE (09-14 park) | SINGLE_CONFIGURATION_UNAVAILABLE:[Errno 2] card | **no card** | N | **B · B3** | no approved card in `cards_approved` (V2 class B; sweep-arm); V2 sweep-arm decision `9e6ddd6b`: Weg 1 premise false (no sealed ledger) → Weg 2 (retire standalone Q08 / Q13-Q14 path) recommended, awaiting OWNER |
| fc6ceb1d… | QM5_41472 | QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1 | Q08_DSR_CONTEXT_UNAVAILABLE (09-14 park) | [Errno 2] card | **no card** | N | **B · B3** | same; awaiting its Q02 replay per V2 sweep-arm doc |
| 249c556b… | QM5_41473 | XTIUSD.DWX | Q08_DSR_CONTEXT_UNAVAILABLE (09-14 park) | [Errno 2] card | **no card** | N | **B · B3** | 41473 = EQUIVALENT_EXACT (identity-equivalence binding pending) |
| 5c8271e0… | QM5_41474 | XAGUSD.DWX | Q08_DSR_CONTEXT_UNAVAILABLE (09-14 park) | [Errno 2] card | **no card** | N | **B · B3** | 41474 = NOT_EQUIVALENT → own chain per V2 sweep-arm doc |
| b1bd1d06… | QM5_12712 | QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1 | Q08_DSR_CONTEXT_UNAVAILABLE | CANDIDATE_WINDOW_UNAVAILABLE | APPROVED / declared | N | **B · B7** | **superseded** 09-14 → d04cd0d0 (failed SUPERSEDED_REPAIR) under V2; residue with a stale unreleased hold; no repair |
| b68d05cd… | QM5_12712 | QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1 | Q08_DSR_CONTEXT_UNAVAILABLE_20260915 | CANDIDATE_WINDOW_UNAVAILABLE | APPROVED / declared | N (ex5 only) | **B · B7** | **superseded** 09-14 → 1679215f (failed SUPERSEDED_REPAIR); residue; no repair |
| 737a2134… | QM5_11167 | XAUUSD.DWX | Q08_DSR_CONTEXT_UNAVAILABLE_20260915 | SINGLE_CONFIGURATION_UNAVAILABLE:LOCKED_PARAMETER_DRIFT | APPROVED / XAUUSD.DWX/D1 | N | **B · B6** | declared locked_parameters drifted vs current source/setfile (e.g. `strategy_fast_sma_period` 8→9, `strategy_slow_sma_period` 29→26, `strategy_atr_sl_mult` 2.523967→3.0); row **superseded** 09-14 → 788c81ee (failed SUPERSEDED_IDENTITY); repair (if EA revived) = re-amend only |
| 0e3f3359… | QM5_1328 | USDCAD.DWX | Q08_DSR_CONTEXT_UNAVAILABLE | **CLEAN (claimable)** | APPROVED / USDCAD.DWX/H4 (V2 card) | Y | **D · D2** | DSR defect repaired under V2; `poison_pill_quarantine` active (13 consecutive `phase_runner_invalid_report`, 0 successes ever, quarantined 09-14T15:36:26Z); DSR-hold release alone does not unblock; needs its own quarantine disposition |

## 4. Class C determination — none

The documented sealed-stream gap (sealed history ends 2025-12-30) does **not** block any
of the 39: every row that carries a window ends ≤ 2025-12-31 (full-history
2017-01-01..2025-12-31 or bare-year 2018..2022), and the 12 windowless rows are
**enqueue-time defects** (no window ever stamped — B5), not stream gaps. Pre-repair
prerequisite flagged for the 6 synthetic-symbol B5 rows (12712, 12778, 12864, 13059,
13076, 41472): verify custom-history/sealed coverage for the chosen window before
re-enqueue.

## 5. §8.5 neighborhood-evidence finding (09-14 pair — folded into D6 as sub-decision)

- `d02a1128` (QM5_13137/XAUUSD.DWX, the 09-14 pair row released 09-16) finished Q08
  **INVALID**: `8.5_neighborhood / neighborhood_evidence_lineage_invalid:evidence_status_missing_or_invalid`
  (aggregate `sub_gates`, evidence `{}`; `D:\QM\reports\work_items\d02a1128-…\aggregate.json`).
- Mechanism (code-level): the lineage validator requires the artifact's
  `evidence_status == "VALID"` (`framework/scripts/q08_davey/aggregate.py:249-257`);
  the aggregate refuses reuse unless
  `sub_gate_input_runs["8_5_neighborhood"].artifact_reusable_after is True`
  (`aggregate.py:296-306`). This run's `sub_gate_input_runs` shows
  `reuse_check: artifact_missing` → the gate fail-closed to INVALID **even though**
  the support runner subsequently completed (`exit_code: 0`,
  `artifact_now_exists: true`, baseline VALID PF=1.96, 117 trades,
  `8_5_neighborhood` stdout in the same aggregate). The on-disk
  `8_5_neighborhood.json` still records the INVALID lineage status — the evidence
  lineage was never re-stamped VALID for this run's identity.
- Verdict taxonomy per `decisions/2026-07-25_q08_tooling_invalid_is_infra.md`:
  tooling-INVALID is retry-owed infra — but a rerun only succeeds after the §8.5
  neighborhood evidence is **regenerated** under the current run's identity
  (evidence-status VALID + param_source sha binding), which is exactly the new
  repair class recorded in `KIMI_INTERIM_HANDOFF_2026-09-18.md:135`.
- Sibling `a6f023c9` (QM5_11121) reached an economic **FAIL_HARD** (legitimate; its
  §8.5 gate did not block). No other row of the 39 is affected.
- 13137 has no live pending Q08 row (chain: 15f2ecb0/f8cb2092 superseded; d02a1128
  done/INVALID) — an append-only rerun post-regeneration is the repair.

## 6. Artifacts

- `audit_rows_raw.json` — per-row raw evidence dump (precheck, card facts, identity, SPEC/mq5/ex5 existence, setfile params, DL-089 ledger lookup).
- `classification_live.json` — live 91-row Q08 classification with the reconciliation buckets.
- Generator scripts (read-only): `.scratch/dsr_remainder_audit_0916.py`, `.scratch/dsr_remainder_classify_0916.py`.
