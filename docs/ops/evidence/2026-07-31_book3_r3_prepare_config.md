# Book3 R3 — IS streams and prepared diagnostic config

Date: 2026-07-31  
Router task: `d9c409f7-f372-4eac-a7cb-52af0314dccf`  
Implementation approval reviewed: task `cca77792-d675-4212-ade5-038b208f232e`  
Mode: artifact preparation only; **no `evaluate` invocation and no diagnostic result**

## Result

The three reviewed per-run streams were pinned to their exact 1,143 / 291 /
548 row identities and materialized as separate IS-only files. A row is present
only when both `entry_time` and close field `time` fall within the original
Prague-date IS window:

- start: `2017-10-09 00:00:00 Europe/Prague`
  (`2017-10-08T22:00:00Z`);
- end: `2022-09-15 23:59:59 Europe/Prague`
  (`2022-09-15T21:59:59Z`).

The original line bytes and ordering are preserved. One XTIUSD position entered
inside the IS window but closed after the boundary and was excluded. No other
stream had a boundary-crossing row.

| Sleeve | Parent rows / SHA-256 | IS rows | IS artifact SHA-256 |
|---|---|---:|---|
| 9936 / USDJPY | 1,143 / `1593ee930e1550236f1c851805d3a71ccdb4c2a244de6994b3dbbf4bf450f7ff` | 654 | `23da92262b8034ed235c669c82f0d0e527053a2563559b65fd732fcabcda4b7a` |
| 10145 / XAUUSD | 291 / `cba8eac2aab23b68c6846ac7848e7da818cc4608912a9dd83e4f89e75d4af425` | 150 | `48ec554bca0de0f1ab3e82253053587635e61d9b711031551a9d406d66741c95` |
| 13108 / XTIUSD | 548 / `136cc04da36b766572843cd496a3770aca694d2eb279f389be4cc2d36ca72179` | 298 | `eec5e17dd582a07531a193a7442bb6128c2dea91926672ca6fa69dc81990433c` |

Each IS JSONL has a committed sibling `.sha256` file. The exact full-stream
summary, report, receipt, and shared evaluation-manifest lineage bindings are in
the spec and were checked by `prepare-config`.

## Prepared contract and requested digests

- IS-only spec:
  `docs/ops/evidence/2026-07-31_book3_r3_is_only_spec.json`
  
  SHA-256: `8de74a43737f9b347bbc6912596269997d29f63f095b88eef4b2603ab4eb6424`
- Prepared config:
  `docs/ops/evidence/2026-07-31_book3_r3_prepared_config.json`
  
  SHA-256: `0581c74b7537a309973dc1c8b0893875920ff5e49fa5b04fadc4cdd22b9930eb`

The prepared config freezes a 1,803-Prague-day IS series, target moving-block
length 57 days, HAC bandwidth 57, sensitivities 28 / 114 days, 2,000
replicates, and seed 20260731. Its freeze records
`holdout_metrics_read: false`. The evaluation window remains the explicitly
unsealed historical diagnostic window beginning Prague day 2022-09-16; the
claim remains `HISTORICAL_DIAGNOSTIC_NOT_SELECTION_SEALED`, strict
qualification `UNVERIFIED`, and paid challenge `NO_GO`.

## Commits

- `44a9106fb` — IS streams, their SHA sidecars, and IS-only spec.
- `1df9dabd1` — prepared config and its SHA sidecar.

Both commits are in canonical checkout `C:\QM\repo` on the registered
`agents/board-advisor` conduit branch.

## Verification

- Independent byte-for-byte derivation comparison against each hash-bound full
  stream: `EXACT_SUBSET_PASS` for all three sleeves.
- Parent counts and SHA-256 contracts: PASS.
- IS row counts, boundaries, and SHA sidecars: PASS.
- `book3_bound_eval.py prepare-config`: `PREPARED`, config digest as above.
- `validate_config()` plus `verify_all_inputs()`: `CONFIG_CONTRACT_PASS`.
- `python -m pytest tools/strategy_farm/tests/test_book3_bound_eval.py -q`:
  `16 passed`.

No backtest, requeue, database write, Factory action, terminal launch, T5,
T_Live, AutoTrading, pipeline verdict, paid-challenge action, or evaluator
`evaluate` command occurred. The next permitted action is Claude review of the
committed config digest; this artifact does not authorize a diagnostic run by
Codex.
