# Option (b) executed — 51 EAs rebuilt, 78 Q08 regeneration rows enqueued

Execution record for the pre-registered plan
(`docs/ops/evidence/2026-08-17_PREREG_book_q08_regeneration_91_pairs.md`). Membership was frozen
before any action in `artifacts/book_q08_regeneration_cohorts_20260817.json`.

## What ran

| step | result |
|---|---|
| C1 determinism gate | **PASSED** — 4/4 identical stream hashes on unchanged binaries, 0 divergences |
| C3 rebuilds | **51/51 PASS**, 0 errors, 0 warnings, 8.5 min total (~11 s per EA, serial) |
| binaries actually changed | **51/51** SHA changed, **51/51** now post-cutoff |
| rows enqueued | **78** — C1 12, C2 25, C3 41 |
| audit events | 78 (`book_q08_regeneration_enqueued`) |

`build_check` was deliberately never invoked. `compile_one.ps1` is per-EA by construction, so the
unscoped-sweep hazard that mutated 9,072 setfiles on 2026-08-13 is structurally excluded rather
than merely avoided.

**Ordering guarded against a real race:** C1 and C2 were enqueued first (no rebuild needed), and C3
was held back until all 51 compiles finished. Enqueuing C3 earlier would have allowed a row to be
claimed against a stale binary and produce exactly the non-rich stream this exercise exists to
replace.

## 13 of 91 could not be enqueued, each with a named reason

| reason | pairs |
|---|---:|
| `deterministic_setgen_defect` | 10 |
| `no_prior_q08_row` | 3 |

**The 10 setfile defects are point 1.3 arriving on the critical path.** Nine are
`empty_strategy_params` — the setfile's strategy block has no non-framework parameters — and one is
a parse error. These pairs deterministically fail Q08.5 and cannot produce a stream until their
setfiles are regenerated. 1.3 is filed in v6 §6 as "parallel and cheap"; it is in fact blocking
**10 of 91 book candidates**, and no amount of tester capacity substitutes for fixing it.

The 3 without a prior Q08 row (`12778:AUDUSD`, `12781:USDJPY`, `13117:EURGBP`) entered the pool via
the FAIL_PORTFOLIO or density-returner routes, which never required Q08.

**So the regenerated pool will be 78 pairs, not 91, until 1.3 lands.**

## The operator

`tools/strategy_farm/prepare_book_q08_regeneration.py`, plan/apply, dry-run default. It exists
rather than hand-rolled INSERTs because the enqueue path carries mandatory gates and
`sweep_enqueue_built_eas.py` — which holds the proven row shape — has **no `__main__` guard**, so
importing it would execute the entire sweep. The gates are therefore called directly:

- `.DWX`-only (a bare broker symbol has no local history and INFRA_FAILs on history sync)
- `farmctl.custom_history_archive_admission` — the Variant-A containment gate, fail-closed
- `q08_recovery_lineage.build_q08_recovery_lineage` — a malformed lineage aborts the row
- the Q08.5 deterministic setfile-defect check
- duplicate suppression on `(ea, symbol, Q08)` pending/active

Writes run under `BEGIN IMMEDIATE` with in-transaction revalidation, a pre-commit read-back that
every created row is `pending`, rollback on any failure, and one audit event per row.

Verified after apply: all 78 rows claimable against the real claim selector, all setfiles present
on disk, every row carrying the `custom_history_archive_admission` stamp.

## Cost and queue behaviour

No queue reordering was performed. A fresh Q08 row scores `10 + 2 - age = 12` in the claim order;
measured against the live queue, **365 rows rank ahead, 36 tie, 1,580 fall behind**. Q08 phase-rank
2 already beats Q04 (6) and Q02 (8) by design — "downstream phases first so work drains". E7
therefore stands untouched, and `set_priority_track.py` (capped at 10 exact ids and bound to a
specific OWNER decision) was correctly not used.

Expected completion: 1.5–2 days at the observed 15–19 completions/hour.

## What is now measurable that was not

Each of the 78 runs carries a recorded binding, so for the first time the pool's streams will have
provenance. The C3 flip count — how many of the 41 rebuilt pairs change their Q08 verdict — is the
measurement the vintage question has been asking for since 2026-07-27, and it will be read against
the pre-registered bands (≤5 = gate noise, ≥15 = the pool needs revalidation before 3.2).

Prior evidence already narrows the expectation: of three historical recompiles, two changed the
stream and **neither changed the verdict**
(`docs/ops/evidence/2026-08-17_C1_gate_passed_and_recompiles_change_streams_not_verdicts.md`).

## Evidence

- pre-registration and cohorts as above; receipts under
  `D:/QM/reports/state/book_q08_regen_{C1,C2,C3}_receipt.json`
- rebuild log: 51 rows, all PASS, in the session scratchpad; per-EA compile logs under
  `framework/build/compile/20260817_*`
- operator: `tools/strategy_farm/prepare_book_q08_regeneration.py`
- claim order: `tools/strategy_farm/farmctl.py:1088-1112`, `:1178-1182`
