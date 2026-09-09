# QM5_10025 Q02 physical-host dependency requalification fix

Date: 2026-09-09

Branch: `agents/board-advisor`

Router task: `258526d6-acfd-4eba-9c3a-7d612109e959`

Outcome: `FARM IDENTITY DEFECT FIXED; Q02 REQUALIFICATION REFUSED CLOSED`

## Target and duplicate control

The selected recovery target was the low-frequency H4 market-neutral FX EA
`QM5_10025_rw-fx-broad-pairs`, host `USDJPY.DWX`. Its latest Q02 row,
`e49888a1-6dbe-45b7-bb4f-29461bbcfb0c`, is terminal `INFRA_FAIL` with
`EVIDENCE_UNAVAILABLE:worker_crashed_handling_item`. No open USDJPY Q02 row and
no active router claim for this EA/symbol lineage existed before task
`258526d6-acfd-4eba-9c3a-7d612109e959` was created.

The row failed while the old worker attempted an SH3-incomplete terminal write:

`sqlite3.IntegrityError: CHECK constraint failed ... verdict_taxonomy ... IS NOT NULL`

The canonical worker now writes `verdict_taxonomy='infra'` in that path; the
repair is present in commit `e358c9e3cd`.

## Requalification identity defect

`basket_manifest.json` explicitly defines this EA as a seven-host dependency
manifest, not a synthetic logical-basket manifest. Each Q02 row therefore uses
one real `.DWX` host and intentionally omits `logical_symbol`.

`farmctl._q02_execution_symbol_binding` previously treated the mere presence
of any `basket_manifest` or `basket_symbol_count` as proof of a synthetic
basket. Consequently, the governed `requalify-q02` path refused the valid
physical-host row with:

`historical_execution_identity_missing / logical_symbol`

The helper now recognizes a physical-host dependency only when every sealed
identity agrees: no logical symbol, non-basket portfolio scope, row symbol =
host symbol = expected symbol, row symbol is a declared dependency member, and
the declared dependency count exactly matches the member list. Synthetic
baskets with no logical symbol remain fail-closed.

## Verification

- `test_q02_post_binding_requalification.py`: 9 passed.
- `test_candidate_repair_enqueue.py`: 50 passed.
- PACER input-pin audit on the canonical MQ5: exit 0, zero
  `EA_FRAMEWORK_INPUT_PINNED` findings.
- Current MQ5 SHA-256:
  `db7424efcba0a8df90184240e277e1a7546e8030672eec88a4c72a89c32a5a61`.
- Current EX5 SHA-256:
  `49fcc59b5232531f5fd2e3ba7a0c71f0bac703f54e17f7c92c911e31944d91f1`.
- Governed compile work item
  `21c7d995-2fd6-44f6-b624-8c5f097c0961`: `COMPILE_OK`, build check PASS,
  zero compile errors, zero warnings, exact current MQ5/EX5 hashes.
- Current USDJPY H4 set SHA-256:
  `4ca9d75bdb2274888ab9afc339034e7f1dc2af93ada2ff62b5672bb2976b92a5`.
- Set risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

A fresh local build check was not retried after the live-factory guard returned
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` while governed MT5 jobs were active. The
existing governed compile receipt above remains the build authority.

## Fail-closed Q02 disposition

After the identity fix, the exact worker-crash row advanced to the next strict
gate and was refused with:

`source_setfile_bytes_unrecoverable`

The immutable source set binding is
`9567e0f91b1e6892eadc822a2f6ee4f06482a80ba30c50ccfbf4a205d2acda70`.
The transient instrumented preset is absent from the canonical file, Git
history, the exact work-item report, T10 staging, and retained farm artifact
copies checked during this task. The older evidence-backed Q02 predecessor
`050dd2ea-e9d0-475f-b5ad-40c2206867ff` is recoverable, but requalification from
it correctly refuses the added `strategy_debug=true` parameter because the
current compile receipt has no hash-bound parameter-change authority artifact.

No historical row was edited. No Q02 row or compile row was enqueued, no tester
was launched, and no portfolio gate, T_Live manifest/terminal, AutoTrading
state, or live-use authority was touched. Further enqueue work requires an
authorized, hash-bound recovery of the transient preset semantics or a new
governed compile receipt carrying the parameter-change authority; this task did
not manufacture either.
