# Codex independent review — batch 2

Date: 2026-07-25  
Branch: `agents/board-advisor`  
Mode: source review, permitted test suites, filesystem inspection, and SQLite `mode=ro` queries only. No apply, commit, compile, MT5 terminal, backtest, or `C:\QM\mt5\T_Live` access was performed.

The factory moved the branch during this review. In particular, the 1567 source and guardrail-set changes were incorporated by factory commit `9c5b934cb` before the review finished, together with unrelated factory output. I did not rewrite or otherwise alter that history. The reviewed load-bearing blobs remained unchanged while HEAD continued moving.

## 1. Verdicts

| # | Package | Verdict | Finding |
|---:|---|---|---|
| 1 | Basket-magic fix | **CHANGES-REQUIRED** | The host-plus-consistency fallback is not fail-closed: when a fallback EA's genuinely traded second leg has no registry row, the helper still passes because the missing leg is indistinguishable from an absent conversion leg. Require authoritative `traded_symbols`, or a complete `basket_symbols - conversion_symbols` derivation; otherwise reject as unknown and update the ten incomplete manifests. |
| 2 | 1567 seed wiring | **APPROVE** | All 14 supplied `QM_FrameworkInit` positions match the signature, and stress probability zero short-circuits before any RNG draw. Default-path Q02-Q04 behavior is unchanged. A newly compiled `.ex5` still requires fresh Q10 evidence to bind the new binary hash. |
| 3 | 44 guardrail setfiles | **APPROVE** | All 44 intended files were present; three files per EA matched the survivor's parameter block and the corresponding `.mq5`/SPEC defaults. Both directory validations passed with zero findings. |
| 4 | C2-narrow taxonomy | **APPROVE** | The change is additive, limited to the four exact tooling-detail prefixes, and preserves `FAIL_HARD > blocking INVALID > tooling INFRA_FAIL`. Farmctl's loss of the dominant Q08 sub-gate reason is a concrete observability follow-up, not a classification/safety blocker. |
| 5 | Stranded requeue tool | **CHANGES-REQUIRED** | Database flip/claim semantics and the poison guard hold, but apply/revert is not crash-safe or byte-faithful for archived report roots: filesystem moves can survive a DB rollback, the archive map is persisted only after the DB commit, and revert commits the DB before best-effort unarchive while swallowing restore failures. |
| 6 | Q07 second axis, `5f677d865` | **APPROVE** | Implementation exactly matches the ratified boundaries: any losing seed fails; variance below 20 passes; `[20,40)` passes only when the worst seed is at least 1.10; variance at least 40 fails. Reason strings distinguish the primary, second-axis, and losing-seed paths. |
| 7 | WP-1b Q04 fanout audit | **CHANGES-REQUIRED** | The 68.8% headline measures pairs with multiple rows, not multiple distinct setfiles. At its stated cutoff the true multi-setfile result is 716 pairs / 10,298 rows / **67.875%**; 71 pairs / 142 rows in the headline population are retry-only duplicates. |
| 8 | FINAL24b generators, `82fc893ae` | **APPROVE** | The base-reproduction gate precedes output, the unrounded solve reaches the 12.0 cap, and all 24 staged preset hashes and manifest values match the staging report. The new `25_USDCAD` preset has magic `114220004` and `RISK_PERCENT=0.195664`. |

## 2. Load-bearing verification

### Basket-magic

- The current read-only inventory contained 14 logical baskets. All 14 clear `active_magic_missing`; ten reach the imprecise fallback and four use `traded_symbols`.
- For 192 plain-symbol discoveries, the new result matched the previous exact-symbol registry behavior with zero differences.
- The blocking counterexample is structural, not hypothetical test noise: remove the registry row for a fallback basket's second traded leg while leaving the host active and no contradictory inactive rows. `_basket_required_legs` cannot name the missing leg, and the host-plus-consistency branch returns success. That contradicts this module's fail-closed qualification contract.

### 1567 wiring and guardrails

The 1567 call maps as follows:

1. EA name
2. magic offset
3. risk percent
4. fixed risk
5. portfolio weight
6. news mode
7. Friday-close enabled
8. Friday-close hour
9. pause before = `30`
10. pause after = `30`
11. stale horizon = `24*14`
12. impact filter = `"high"`
13. RNG seed = `qm_rng_seed`
14. stress reject probability = `qm_stress_reject_probability`

Positions 9–12 equal the defaults in `QM_Common.mqh`; positions 13–14 expose the new inputs. The later temporal/compliance arguments retain their signature defaults. At stress probability zero, the `p > 0.0 && ...` condition short-circuits before `QM_Rand*`, so adding the explicit seed and zero-stress inputs does not change the Q02-Q04 execution path.

That is behavioral continuity, not permission to attach old Q10 evidence to a newly compiled binary. After the approved 1567 compile, run Q10 against the new `.ex5`; rerun Q02-Q04 only if that revalidation materially deviates.

Spot checks:

- 10815: EURUSD H1, NDX M15, and XAUUSD M15 matched the GDAXI H1 survivor block and all 14 relevant `.mq5` defaults.
- 1567: AUDCAD, NDX, and XTI matched the EURUSD survivor block and all 10 relevant `.mq5` defaults.
- `validate_build_guardrails.py` result: 10815 PASS, 42 files checked, zero findings; 1567 PASS, 82 files checked, zero findings.

### C2 taxonomy

Only these exact detail prefixes are reclassified:

- `neighborhood_evidence_lineage_invalid`
- `pbo_refresh_lineage_invalid`
- `perturbations_runner_output_missing`
- `insufficient_distinct_configs`

`baseline_setfile_defect` remains blocking, as do unknown INVALID details and a computed FAIL. A mixed case confirmed computed failure wins over a tooling-invalid detail. The target and neighboring verdict suites passed.

The declared farmctl follow-up is real. For a Q08 top-level `INFRA_FAIL` caused by `q08_8.7_pbo:insufficient_distinct_configs`, `_derive_phase_runner_verdict` currently returns the generic pair `("INFRA_FAIL", "INFRA_FAIL")`, even though `_q08_dominant_invalid_reason` can recover the specific sub-gate reason. Fix that in a separate farmctl-plus-test change; it does not make the aggregate verdict unsafe.

### Requeue tool

The parts that hold:

- Rows with `attempt_count >= 12` are refused. Exact `LOG_BOMB` markers in either reason field are also refused. This contains terminal-worker's attempt-99 poison sentinels even though `_priority_pending_query` has no attempt gate.
- The successful flip payload matches the pending state expected by terminal-worker claim: pending status, cleared verdict/evidence/claim fields, attempt zero, and cleared stale runtime keys.
- Two-pass, transaction-local revalidation protects the database selection against state changes before the flip.
- Setfile grain is correct. In one moving read-only snapshot there were 1,418 eligible rows; collapsing by EA-symbol-phase would discard 283 distinct setfile rows, with 84 phase groups containing multiple setfiles.

The blocking archival defects:

1. Apply renames report roots before committing the DB transaction. On a later exception the DB rolls back, but already moved roots are not compensated.
2. The pre-apply snapshot does not contain the final archive map. That map is written only after the DB commit, leaving a crash window in which the rows have flipped but the information needed for faithful revert is absent.
3. Revert commits database restoration before attempting filesystem restoration. Unarchive failures are swallowed, so it can report restored state while roots remain archived.
4. A failed archive rename does not make the row flip fail.

The repair should make archive failure fatal, persist a durable pre-commit journal/archive map, compensate partial moves, require the exact expected post-apply row state during revert, and surface/compensate any unarchive failure.

### Review debts

- Q07 boundaries were exercised at 20, 40, worst-seed 1.10, and below-floor cases; the raw comparisons and precedence match the ratified rule.
- The WP-1b audit's stated cutoff (`created_at <= 2026-07-25T13:00:00+00:00`) reconstructed to 15,172 Q04 rows and 5,519 EA-symbol pairs. Its quoted 787 pairs / 10,440 rows / 68.811% is the `COUNT(*) > 1` result. Requiring `COUNT(DISTINCT setfile_path) > 1` gives 716 pairs / 10,298 rows / 67.875%. The synth result still checks as one PASS out of 1,334, and the farmctl promotion loop is globally uncapped; its `LIMIT 10` is per pump iteration.
- FINAL24b independently reproduced the base with maximum weight error `4.9207e-7` and Sharpe `2.3737470634`. The final unrounded weight sum was effectively 12.0 and the recomputed Sharpe was `2.3439999867`; three positions were at the 1.0 cap. All 24 staged files matched their reported SHA-256 values and manifest rails. Spot checks covered GDAXI, NDX, and the new USDCAD preset; the active registry row for USDCAD slot 4 maps to `114220004`.

Permitted targeted tests:

```text
165 passed in 8.04s
```

This covered the FTMO qualification tests, requeue tests, Q08 Davey sub-gates, neighboring verdict taxonomy, and Q05/Q07 verdict tests.

## 3. Endorsed commit grouping and order

Because the factory moved and partly committed the reviewed files, this is the logical grouping I endorse for any cleanup/cherry-pick or subsequent branch:

1. **C2 taxonomy:** `aggregate.py`, its six tests, and the C2 decision record together. The farmctl reason-preservation follow-up may be a separate small commit.
2. **10815 guardrails:** the 13 10815 setfiles as one unit. Once that exact unit is fixed in history, `compile_ea.py --force` targeting 10815 may run.
3. **1567 build unit:** seed wiring plus all 31 1567 guardrail setfiles in one commit/build unit. Then run one `compile_ea.py --force` targeting 1567, followed by fresh Q10 on the resulting binary. Do not compile the source and setfiles as separate builds.
4. **WP-1b document correction:** correct the multi-setfile population and retain the 68.8% figure only if relabeled as multi-row/retry-inclusive.
5. **Basket-magic:** no commit until the unknown-leg path fails closed and a negative missing-second-traded-leg test is added.
6. **Requeue tool:** no commit or canary until archival apply/revert is made crash-safe and re-reviewed.
7. **This independent review record.**

The already committed Q07 second-axis and FINAL24b generator commits require no corrective regrouping from this review.

## 4. Requeue canary decision

**The canary-50 must wait for a Factory-OFF window with workers and pump quiescent.**

The two-pass database revalidation is useful but insufficient. Report-root renames are outside SQLite's transaction, and at Factory-ON a worker can claim a newly pending row immediately after commit, eliminating a reliable rollback window. This decision remains Factory-OFF even after the archival defects are fixed; apply only with the required snapshot/journal, then verify the canary before restarting the factory.

## 5. Not independently verified

- No EA was compiled and no Q02-Q10 phase or backtest was run.
- The requeue apply/revert path was not executed against real rows or report roots; review used source, tests, dry-run behavior, and `mode=ro` database queries.
- `C:\QM\mt5\T_Live` was not accessed. Therefore the FINAL24b report's claims about its deployed-source inputs were not independently checked; the staged directory, manifest, generator math, registry mapping, and staging-report hashes were checked.
- Live DB totals continued to move. Counts without the WP-1b document's explicit cutoff are observations, not durable inventory totals.
