# Q02 `log_bomb` family — remediation result

Date: 2026-07-27
Author: Claude (board-advisor worktree)
Task: fix the log-bomb family, guided strictly by
`docs/ops/evidence/2026-07-27_logbomb_family_diagnosis.md`; reference fix commit `54efb0c66`
(QM5_11072).

---

## Headline

**In-place EA fixes applied: 0. Compile failures: 0 (nothing was compiled).** This is the
correct, evidence-driven outcome, not an abort: the diagnosis established — and I
independently re-verified against the live DB and the EA sources — that the 4,236-row /
139-EA `log_bomb` family is a **reclassifier false-positive**, not a population of bombing
EAs. There is no broken EA source to repair in place anywhere in the family.

The real repair is the one the diagnosis prescribes (§7 Class C / §9 point 1): a one-line
change to the historical reclassifier. It is landed in this batch. It removes the false
label from all 4,236 rows and prevents the mislabel recurring.

### Measure of success

> how many of the 4,236 `log_bomb` rows belong to EAs that are now fixed (in place)?

**0.** No EA in the family was broken, so none was fixed in place — fixing a clean EA would
have manufactured a phantom repair and, for the 122 EAs holding real verdicts, risked
corrupting genuine gate evidence.

The rows the actual remediation addresses: **4,236 / 4,236.** The committed reclassifier
fix removes the spurious `log_bomb` label; a dry-run over the graveyard proves all 4,236
re-bucket to their true classes and `log_bomb` drops to **0**. The one remaining step —
re-stamping those rows in the live DB via `--apply` (reversible, payload-only, never
requeues) — was **blocked by the sandbox write-classifier** and needs OWNER approval to run
(see §5).

---

## 1. Independent verification of the diagnosis (I did not act on it blind)

Per the Hard Rule "evidence over claims, including your own findings," every load-bearing
claim was re-checked against `D:/QM/strategy_farm/state/farm_state.sqlite` (read-only,
`mode=ro`) and the EA sources before deciding to edit nothing.

| Claim (diagnosis) | Independent check | Result |
|---|---|---|
| Family size | `phase='Q02'` ∧ payload `failure_subclass='log_bomb'` | **4,236 rows / 139 EAs** ✓ |
| Stamp rests only on `attempt_count>=99` | count `attempt_count>=99` in family | **4,236 / 4,236** ✓ |
| No genuine kill artifact in family | count rows with `verdict_reason=LOG_BOMB` ∨ `LOG_BOMB∈reason_classes` ∨ `final_failure=log_bomb` ∨ any `log_bomb_journal*` key | **0 / 4,236** ✓ |
| Rows are the summary-missing transport signature | aggregate `verdict_reason` / `final_failure` | `final_failure=summary_missing_retries_exhausted` on **all 4,236**; `verdict_reason=SUMMARY_MISSING_RETRIES_EXHAUSTED` on 4,233 (+3 stragglers) ✓ |
| Genuine log-bombs are a disjoint population | count `verdict_reason=LOG_BOMB` ∨ `log_bomb_journal_gb` present | **80 rows / 50 EAs**, disjoint (they carry `final_failure=log_bomb`, outside this tool's graveyard) ✓ |
| 122/139 hold real verdicts → variant, not in-place | per-EA count of any non-INFRA/INVALID/SUPERSEDED verdict | **122 / 139** ✓ |
| QM5_10923 holds real verdicts | rows by phase/verdict | Q02 PASS×17, FAIL×2, INFRA×10; Q03 PASS×5; Q04 FAIL×7, INFRA×1 — **real verdicts** ✓ |

Two source spot-checks (the head clean EA and the one alleged bomb):

- **QM5_10296** (`cinar-cmf`, 154 rows, #2 by volume) — `Strategy_ManageOpenPosition`
  contains only `QM_TM_ClosePosition`/`QM_TM_OpenPosition`, **no per-tick modify**. Class
  `clean:no-mgmt` confirmed.
- **QM5_10923** (`grimes-donchian`, the lone `OTHER-BOMB(latent)`) — confirmed exactly as
  diagnosed: `Strategy_ManageOpenPosition()` is called at `OnTick:396`, **before** the
  new-bar gate at `:416`, so it runs every tick; line **301** calls
  `QM_TM_MoveSL(ticket, new_sl, "grimes_trail_after_2r")` with **no `new_sl > current_sl`
  guard**; `new_sl` is built from `g_best_close_since_ent` and
  `QM_ATR(_Symbol, PERIOD_D1, …, 1)` (shift 1 = closed bar) → constant within a D1 bar →
  re-issues the same SL every tick. Distinct from the 11072 spread-jitter mechanism.

The diagnosis was corroborated on every point checked.

## 2. Classification-driven actions (per task steps 1–3)

**Class A — SAME-MECHANISM (11072 spread-jitter vs sub-pip threshold): 0 members.**
Nothing to edit. The `54efb0c66` recipe has no applicable target in this family.

**Class B — OTHER-BOMB, unguarded per-tick modify: 1 member (QM5_10923).**
The diagnosis wrote a mechanical Class-B recipe, but QM5_10923 **holds real Q02/Q03/Q04
verdicts** (17 PASS at Q02 alone). Task step 1 permits in-place repair *only* on EAs with no
real gate verdicts, and task step 3 / diagnosis §7B & §9 require variant treatment for
evidence-holding EAs. Therefore **not edited in place** — listed for variant treatment in §4
with its ready recipe.

**Class C — NO-SOURCE-BOMB / mislabel: 138 members.** No EA edit. The rows are
`summary_missing` transport failures (history-lock re-sync storm, `terminal_worker.py:95-110`)
that the reclassifier mis-stamped. Root repair = the reclassifier fix in §3. The affected
`(EA, symbol)` pairs also auto-heal via the worker's history-lock transient-retry path; no
per-EA work and (per task step 4) **nothing was requeued**.

**In-place-eligible ("stranded") but clean: 17 EAs.** `QM5_10794, QM5_11174, QM5_10850,
QM5_11223, QM5_11091, QM5_9992, QM5_9271, QM5_10518, QM5_10016, QM5_9357, QM5_10782,
QM5_1173, QM5_11029, QM5_9525, QM5_10882, QM5_10031, QM5_11112`. All carry `clean:*` source
classes (no source bomb), so **no in-place edit is warranted** for any of them either.

### Per-class tallies

| Class | Members | In-place fixed + compiled | Skipped (why) |
|---|---:|---:|---|
| A — SAME-MECHANISM | 0 | 0 | none exist |
| B — OTHER-BOMB (mechanical recipe) | 1 | 0 | QM5_10923 holds real verdicts → variant |
| C — NO-SOURCE-BOMB / mislabel | 138 | 0 | no source bomb; fixed at the reclassifier |
| (of which stranded/in-place-eligible) | 17 | 0 | all `clean:*`, no bomb to fix |
| Real-verdict EAs (must variant) | 122 | 0 | do not edit in place |

**Compile failures: none** — no EA `.mq5` was edited, so `compile_one.ps1` was not invoked.
No EA was reverted (nothing was changed).

## 3. The repair that was applied — reclassifier fix (committed)

`tools/strategy_farm/classify_summary_missing.py::_has_log_bomb` previously returned `True`
on a bare `attempt_count >= 99`. That sentinel is not log-bomb-specific — the older
exhaustion/poison paths stamped 99 for ~8 different `verdict_reason` causes — so it swept
4,236 innocent summary-missing rows into `log_bomb`.

The fix (commit `8e0e81f47`) removes the bare-99 branch and requires a **genuine kill
marker**: `verdict_reason == 'LOG_BOMB'`, `'LOG_BOMB' ∈ reason_classes`, or any
`log_bomb_journal*` payload key. This is exactly the marker set the genuine kill path stamps
(`terminal_worker.py:2595-2633`) and matches the forward classifier
(`farmctl.classify_summary_missing_run`, which keys on the `log_bomb=True` log line, not
`attempt_count` — so it needed no change).

- Tests updated in lockstep (`test_summary_missing_classification.py`): genuine-marker rows
  still classify `log_bomb`; a bare `att=99` is now a `never_worked` **regression guard**.
  **27 passed.**
- Dry-run over the Q02 graveyard (population 43,037) with the fix in place:

  | class | rows | subclass | rows |
  |---|---:|---|---:|
  | SUPERSEDED | 29,390 | pair_has_verdict | 29,390 |
  | IN_FLIGHT | 12,533 | pair_open | 12,533 |
  | DETERMINISTIC_NO_SUMMARY | 1,111 | never_worked | 930 |
  | | | input_missing | 181 |
  | TRANSIENT | 3 | transient_token | 3 |
  | **log_bomb** | **0** | | |

  `rows_needing_write = 11,062` (the 4,236 former `log_bomb` re-bucketing + ~6,826 rows whose
  SUPERSEDED/IN_FLIGHT labels drifted since today's earlier run — the tool re-classifies the
  whole graveyard idempotently).

## 4. Variant list (do NOT edit in place — real gate evidence)

122 family EAs hold real verdicts and must be varianted, never edited in place. The only one
with a genuine latent source bomb:

- **QM5_10923** (`grimes-donchian`) — cut e.g. `QM5_10923_v2` and add the monotonic
  hysteresis guard immediately before `QM_TM_MoveSL` at line 301:
  ```mql5
  const double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  const double curr_sl  = PositionGetDouble(POSITION_SL);
  const bool   improves = (curr_sl <= 0.0) ||
      (is_buy ? (new_sl > curr_sl + point * 0.5)
              : (new_sl < curr_sl - point * 0.5));
  if(improves)
     QM_TM_MoveSL(ticket, new_sl, "grimes_trail_after_2r");
  ```
  This fires once per genuine advance instead of every tick, preserving the trail. It is a
  **latent** risk (positions rarely dwell past 2R long enough to hit the 1,500 MB/min rate
  cap on the tested symbols — hence its PASS verdicts), not the cause of its own
  `summary_missing` row.

The remaining 121 evidence-holding EAs need no source change; they were mislabelled by the
reclassifier and are corrected by §3.

## 5. Remaining step (blocked — needs OWNER approval)

Applying the corrected classification to the live DB re-stamps the 4,236 rows out of
`log_bomb`:

```
python tools/strategy_farm/classify_summary_missing.py --phase Q02 --apply
# reversible:  --revert <snapshot written under D:/QM/reports/state/>
```

`--apply` is payload-only (writes `failure_class`/`failure_subclass`/`failure_class_evidence`
only), leaves `verdict`/`status`/`attempt_count`/`updated_at` untouched, **never requeues**,
is guarded on the exact prior payload (skip-not-clobber), and writes a timestamped reversible
snapshot before the first write. I dry-ran it (§3, `log_bomb → 0`) but the **live-DB write
was denied by the sandbox write-classifier**; per that denial I did not attempt any
workaround. Run it in a quiescent window with OWNER approval to complete the DB correction.
Until then the code fix stands and the family will re-bucket automatically the next time the
tool is run with `--apply`.

## 6. Genuine 06-30 log-bomb EAs (informational, not in the 4,236)

Four family EAs additionally own a **separate** genuine 06-30 rate-killed row (part of the
disjoint 80, not the 4,236): QM5_10715, QM5_11699, QM5_9991, QM5_10952. Three have no
per-tick modify at all and the fourth is monotonic-guarded, consistent with an
already-remediated framework storm (the `QM_MagicResolver` per-tick warning flood whose
`warn_new` dedup landed 2026-06-21, `8fe875926`) reaching a stale pre-fix `.ex5`. Recompiling
against current framework before any rerun neutralises it; no source change. Not requeued.

---

## Evidence appendix

- DB (read-only): `D:/QM/strategy_farm/state/farm_state.sqlite`.
- Family: `phase='Q02'` ∧ payload `failure_subclass='log_bomb'` → 4,236 rows / 139 EAs;
  `attempt_count=99` on all; 0 genuine kill artifacts; `final_failure=summary_missing…` on all.
- Disjoint genuine population: 80 rows / 50 EAs (`verdict_reason=LOG_BOMB` / `log_bomb_journal_gb`).
- QM5_10923 verdicts: Q02 {PASS 17, FAIL 2, INFRA 10, None 1}, Q03 {PASS 5}, Q04 {FAIL 7, INFRA 1}.
- Source: `framework/EAs/QM5_10923_grimes-donchian/QM5_10923_grimes-donchian.mq5:268-302, 388-417`;
  `framework/EAs/QM5_10296_cinar-cmf/QM5_10296_cinar-cmf.mq5` (no per-tick modify).
- Reclassifier: `tools/strategy_farm/classify_summary_missing.py:_has_log_bomb` (fixed, commit `8e0e81f47`).
- Tests: `tools/strategy_farm/tests/test_summary_missing_classification.py` — 27 passed.
- Dry-run: population 43,037; log_bomb → 0; rows_needing_write 11,062.
- Diagnosis: `docs/ops/evidence/2026-07-27_logbomb_family_diagnosis.md`; reference fix `54efb0c66`.
