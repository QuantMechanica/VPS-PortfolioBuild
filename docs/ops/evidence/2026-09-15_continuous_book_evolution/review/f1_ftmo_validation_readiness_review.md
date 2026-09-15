# Adversarial review — slice `f1_ftmo_validation_readiness`

- **Reviewer:** adversarial reviewer (Claude/Fable), 2026-09-15
- **Authority:** OWNER-DEC-CBE-20260915; directive §11–§19, §57, §62, §63, §68F, §70; follow-up §13–§14
- **Patch:** `scratchpad/patches_defg/f1_ftmo_validation_readiness.patch`
- **Base HEAD:** `4ad7ab7016a77f25323b95912573eafbb21c5e69`
- **Verdict: ACCEPT_WITH_FIXES** — no blocking items; two major follow-ups; two minor notes. RED boundary NOT crossed.

## What was verified (own commands)

1. **`git apply --check` against HEAD → exit 0.** Patch applies cleanly, no conflicts.
2. **Tests run from the applied tree → `35 passed in 2.09s`** (`test_ftmo_demo_cycle.py`,
   `test_ftmo_fitness.py`, `test_ftmo_rules_snapshot.py`, `test_ftmo_challenge_readiness.py`,
   `test_ftmo_no_purchase_guard.py`), matching the implementer's claim.
3. **Runtime read-models are real, deterministic and honest:**
   - `D:/QM/reports/state/ftmo_demo_cycle.json`: 8 sleeves, `roster_hash 6c5383d8…`, `roster_source
     chart_profile`, real per-sleeve `ex5_sha`. Roster (10706/GBPUSD, 11421/EURUSD, 11422/USDCAD,
     11910/NZDUSD, 13054+20048/USOIL.cash, 1537+21505/XAGUSD) matches `audit/ftmo_demo_state.md` and
     `ftmo_fitness_candidates.md` exactly. Governor 13206 + telemetry correctly excluded.
   - `D:/QM/reports/state/ftmo_challenge_readiness.json`: `recommendation NOT_READY`,
     `would_fable_buy_today.answer=false`, strongest failure = realized max-DD −10.26% total-loss
     breach. `demo_metrics_detail` reproduces cycle-1 net −9.9529% / maxDD −10.2649% (59 trades) and
     cycle-2 −0.1464% / −0.2856% (9 trades) — byte-for-byte consistent with audit F3.
   - `admitted_pairs` is honestly `EVIDENCE_MISSING` (Q10 not wired), `best_fund_score 0.4076` vs
     `floor 1.0`. No invented numbers; every unfilled axis is `NOT_EVALUATED`/`EVIDENCE_MISSING` with
     a named exporter (`demo_metrics._EXPORTER_GAPS`).
4. **RED boundary respected.** Diff touches only the new `tools/strategy_farm/ftmo/` package, its 5
   tests, three docs, one evidence snapshot, and the FTMO rulepack. No `gate_manifest.v4.json`, no
   `book_build_guard.py`, no verdict/farm-DB writes, no T_Live/AutoTrading/terminal64, no live
   deployment. The rulepack rebind changes only snapshot pointers (`snapshot_path`,
   `snapshot_sha256`, `retrieved_at_utc`), top-level `as_of`, and an appended `rule_snapshot_binding`
   block; `git diff` and `test_rebind_updates_pointer_not_gate_thresholds` confirm go-criteria
   thresholds (e.g. `maximum_age_days=7`) are untouched. FUND_SCORE floor 1.0 is read-only, not
   weakened.
5. **No purchase path / no secrets / read-only network.** `test_ftmo_no_purchase_guard` scans the
   whole package (incl. pre-existing `demo_install.py`, `trial_setpath.py`) for transaction/payment
   tokens and HTTP POST → none. `rules_snapshot._urllib_fetch` is GET-only with a static User-Agent,
   no credentials; and it is a connectivity probe invoked only by the `refresh` CLI — the default
   `build_readiness` path performs **no** network I/O and is offline-deterministic. No secrets in the
   patch.
6. **Snapshot sha provenance — verified correct.** Recorded `bound_snapshot_sha256 =
   5e25827b589125e7b77cd379453a234649f35983cf5a443ec6a70b77103a2a8c` is the **LF-content** sha of the
   shipped `2026-09-15_ftmo_official_rules_snapshot.json`, matching the repo's pin-sha convention
   (the predecessor `2026-09-04` snapshot is LF on disk with raw==LF sha `c199b8f5…`, its recorded
   value). See MINOR-1 for the line-ending caveat.
7. Comments are English throughout; supersession is dated and non-destructive (snapshot carries
   `supersedes`/`supersession_note`; prior 2026-09-04 snapshot retained; contract/doc dated).

## Blocking (must fix before apply)

None.

## Major (follow-up)

- **M1 — Read-model metric field names drift from the shared readiness contract.** The task's
  `ftmo_challenge_readiness.json` contract lists `metrics.trade_density_per_day` and
  `metrics.swap_cost`; the slice emits `trade_density_entry_days` and `swap_cost_usd` (plus extra
  keys). Consumers "tolerate absence with EVIDENCE_MISSING", so this is non-blocking, but E1's
  `book_evolution_ftmo` mirror and the Phase-D Mission Control panel will see *absence* for the
  contract-named fields. Recommend aligning names (or adding the contract-named aliases) so
  downstream slices bind without silent gaps.
- **M2 — `metrics.max_dd_pct` / `worst_daily_loss_pct` reflect only the latest (near-dormant) cycle.**
  They render −0.29% / −0.18% (cycle-2), while the decision-relevant figure is cycle-1's −10.26%
  breach. The headline verdict stays honest (`strongest_failure_mode` scans all cycles;
  `demo_metrics_detail.cycles` carries both; `would_fable_buy_today=false`), but a Mission Control
  tile that reads `metrics.max_dd_pct` alone would under-represent risk. Recommend surfacing
  worst-across-cycles alongside the latest-cycle value.

## Minor (note)

- **m1 — Snapshot sha is line-ending sensitive; `sha256_file` uses raw bytes.** The recorded LF sha
  is correct and consistent with repo convention *as long as the file stays LF on disk* (as the
  2026-09-04 predecessor does). Because `core.autocrlf=true` and the evidence JSON is `text: auto`
  (`check-attr` = unset), a future checkout could theoretically produce CRLF, at which point a
  raw-byte recompute would yield a different sha (`88c41416…`). No runtime consumer verifies this sha
  today, so impact is provenance-only. Recommend either LF-normalising in `sha256_file` (aligns with
  the "pin-SHA über LF-Blob-Bytes" convention) or pinning `*_ftmo_official_rules_snapshot.json` as
  `-text`/binary in `.gitattributes`.
- **m2 — Q10 admission not wired into the default build** (`admitted_pairs=EVIDENCE_MISSING`).
  Honestly disclosed in the report's "not done"; the NOT_READY verdict is already sound via the
  realized breach + FUND_SCORE floor. The audit's 0/42 is the single loudest FTMO-fitness fact and is
  reproducible via `q09_ftmo_recommendation.collect()`; wiring it in (read-only) would make the
  read-model self-contained. Follow-up.

## Notes for the orchestrator

- **Read-only integrity restored.** While verifying, a failed `git worktree add` (Windows long-path
  limit under `framework/EAs`) caused a `git apply` to land in the main `C:/QM/repo` working tree. I
  reverse-applied the patch (`git apply -R`); the FTMO rulepack diff is now empty and the added
  package/tests/docs/snapshot files are gone (pre-existing `demo_install.py`/`trial_setpath.py`
  retained). No lasting change to the working tree from this review.
- Tickets **42a437a4** and **3e0c8b83** were correctly left untouched (agent_tasks is orchestrator-
  owned). The slice's own note stands: after the v2 roster is frozen, run `demo_cycle build` then
  `challenge_readiness build` (in that order) to re-evaluate.
- Recommend the two scheduled read-model builds the slice proposes, `demo_cycle` before
  `challenge_readiness`, so readiness reads the persisted ledger (stable `cycle_start`/
  `validation_days`).

## Directive §70 coverage check

- "FTMO two-week Demo state tracked correctly" — cycle state machine (NEW→RUNNING→REPRESENTATIVE→
  DECISION_PACKAGE) + deterministic material-change reset, tested. ✓
- "paid purchase cannot occur through automation" — no purchase path; guard test enforces; GET-only
  network. ✓
- "only one paid-Challenge policy represented" — `policy_config` single 100k/2-Step/Standard default;
  `ONE_PAID_CHALLENGE_AT_A_TIME=True`; guard test rejects competing size defaults. ✓
- Fitness separated from DXZ — `ftmo_fitness.compute_ftmo_fitness` asserts no DXZ-only axis leaks;
  `venue=ftmo`. ✓
