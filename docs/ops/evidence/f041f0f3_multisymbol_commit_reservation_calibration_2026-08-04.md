# Multisymbol commit-reservation calibration

Date: 2026-08-04

Router task: `f041f0f3-05e8-4181-b059-e94e55bd5438`

State prepared: REVIEW (no runtime activation performed)

Verdict: `CALIBRATION_READY_OWNER_RELOAD_REQUIRED`

## Outcome

The blanket 44 GB launch reservation is replaced by additive, fail-safe workload
classes in `tools/strategy_farm/terminal_worker.py`:

| Runtime class | Deterministic mapping | Reservation | Evidence floor |
|---|---|---:|---:|
| `two_leg_fx_pair` | exactly two declared `basket_symbols`, both FX; plus the audited legacy QM5_11240 FX hosts | 8 GB | observed p95/max 7.36 GB + 0.64 GB margin |
| `multi_leg_fx_basket` | 3-9 declared `basket_symbols`, all FX | 32 GB | observed p95 24.81 GB; observed max 28.23 GB |
| `heavy_or_unknown_multisymbol` | any non-FX member, 10+ members, incomplete/mismatched metadata, or otherwise unknown | 44 GB (unchanged) | manifest-backed p95 34.99 GB/max 38.52 GB; legacy-unknown p95 30.89 GB/max 39.35 GB |

The admission model is still additive. The reservation still decays only as
`max(0, expected_peak_gb - measured_subtree_gb)`. The 300/3600-second windows,
24 GB general pause threshold, 48 GB multisymbol launch threshold, and the
one-multisymbol-at-a-time farm-wide serialization are unchanged. Unknown or
malformed metadata cannot select a lower reservation.

The active example from the ticket, QM5_11240/NZDUSD, currently retains its
persisted 44 GB reservation. A read-only call through the patched classifier
returns `two_leg_fx_pair` / 8 GB for its next post-reload claim. QM5_11240 metal
and index hosts remain in the 44 GB class.

## Measurement evidence

Sources:

- `D:/QM/strategy_farm/logs/terminal_worker_T1.log` through
  `terminal_worker_T10.log`
- `D:/QM/strategy_farm/state/farm_state.sqlite` (`work_items` payload and identity)
- the matching `framework/EAs/<EA>/basket_manifest.json` files

Method:

1. Parse JSON worker events containing `commit_reservation_detail` and retain
   records whose historical `expected_peak_gb` was 44.
2. Deduplicate by work-item ID and take the maximum non-null `measured_gb` seen
   for that run. This is an observed lower bound when logging stopped before a
   process peak; it is not inflated into an inferred peak.
3. Join each ID to the farm database and its basket manifest. Classify from the
   complete dependency list, not from EA names. Percentiles below use
   nearest-rank p90/p95.

The ten worker logs cover reservation expiries from 2026-07-26 through
2026-08-04 and contain 209 unique historically 44-GB-reserved work items. Two
items had no non-null measurement. Of the remaining 207, 84 had resolvable
manifest metadata and 123 were legacy/no-manifest rows; those 123 deliberately
remain in the heavy/unknown runtime class.

| Measured group | n | min | median | p90 | p95 | max |
|---|---:|---:|---:|---:|---:|---:|
| exact two-symbol FX pair | 5 | 0.35 | 7.07 | 7.36 | 7.36 | 7.36 |
| 3-9-symbol FX basket | 29 | 0.24 | 12.23 | 22.92 | 24.81 | 28.23 |
| manifest-backed heavy/10+/non-FX | 50 | 0.19 | 3.21 | 28.33 | 34.99 | 38.52 |
| legacy/no-manifest (kept unknown-heavy) | 123 | 0.06 | 4.51 | 27.54 | 30.89 | 39.35 |

Representative upper observations:

| Group | Work item / EA | Observed max | Relevant manifest shape |
|---|---|---:|---|
| two-symbol FX | `a34c39c1` / QM5_20196 | 7.36 GB | EURUSD + USDJPY |
| 3-9 FX | `21db772c` / QM5_20211 | 28.23 GB | 6 FX dependencies |
| heavy | `962344a7` / QM5_11147 | 38.52 GB | 10 legs including indices, gold, and oil |
| unknown-heavy | `644ed032` / QM5_12531 | 39.35 GB | legacy/no manifest; XAU host |

The sample for exact two-symbol FX is small, so the implementation lowers only
rows with a complete, count-consistent symbol list (or the one ticket-audited
legacy mapping). A bare `basket_symbol_count=2` is insufficient and stays at
44 GB.

## Fleet-concurrency arithmetic

For a launch-time snapshot with commit headroom `H`, a multisymbol reservation
`R`, an ordinary reservation of 8 GB, and the unchanged 24 GB admission floor,
ordinary claims can continue only while the pre-claim effective headroom is at
least 24 GB. This intentionally ignores later measured decay so it is a
conservative comparison of the launch race itself.

| Live commit headroom | Blanket/heavy 44 GB | 3-9 FX 32 GB | two-symbol FX 8 GB |
|---:|---:|---:|---:|
| 59 GB (ticket sample range) | 1 total slot | 2 total slots | 5 total slots |
| 68 GB | 2 total slots | 3 total slots | 6 total slots |
| 80 GB | 3 total slots | 5 total slots | 8 total slots |

“Total slot” means the serialized multisymbol job plus sequentially admissible
ordinary launches, capped by the ten-worker fleet. Actual counts vary with OS
commit and measured reservation decay; these figures are capacity arithmetic,
not pipeline verdicts or a throughput promise.

## Implementation and verification

Implementation points:

- measured constants and fail-safe mapping:
  `terminal_worker.py:92`, `terminal_worker.py:571`
- additive reservation lookup and audit field:
  `terminal_worker.py:614`, `terminal_worker.py:856`
- class persisted on claim and cleared with other stale runtime fields:
  `terminal_worker.py:887`, `terminal_worker.py:925`
- regressions:
  `test_terminal_worker_atomic_claim.py:629`, `:670`, `:733`, `:752`

Verification run from `C:/QM/repo`:

```text
python -m py_compile tools/strategy_farm/terminal_worker.py tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py
PASS (exit 0)

python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q -k "two_leg_fx or multisymbol_commit_class_mapping or legacy_qm5_11240 or frozen_commit_probe_cannot_overbook_after_multisymbol_claim or stale_runtime_cleanup"
6 passed, 56 deselected in 7.64s

python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q -k "not watchdog_reset_handover_has_transactional_claim_interlock"
61 passed, 1 deselected in 34.80s

git diff --check -- tools/strategy_farm/terminal_worker.py tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py
PASS (exit 0)
```

The unfiltered file run produced `61 passed, 1 failed`. The sole failure is the
pre-existing
`test_watchdog_reset_handover_has_transactional_claim_interlock`, whose source
ordering assertion finds an earlier `start_terminal_workers.py` occurrence in
the unchanged `Factory_ON.ps1`. This patch does not modify Factory_ON or that
test method; the focused reservation suite and every other test in the file
pass.

## Activation boundary / pending OWNER window

`terminal_worker.py` is resident. Read-only process evidence found all T1-T10
worker daemons were created on 2026-08-03, before this patch. They have the old
module loaded, so this change is intentionally inert for the running fleet.
No worker, terminal, scheduled task, Factory flag, or active backtest was
started, stopped, or restarted in this ticket.

Activation belongs in the pending OWNER-authorized window only:

1. review/adopt the committed source and tests;
2. mint a fresh runtime decision binding the final adopted source identity;
3. execute the authorized Factory OFF/ON handover after active work drains;
4. verify a newly claimed exact two-symbol FX row records
   `commit_reservation_class=two_leg_fx_pair` and
   `commit_reservation_gb=8.0`, while a 10-leg/metal/index/unknown row records
   44.0; then run normal health checks.

This artifact does not authorize that window and does not claim immediate
throughput improvement.
