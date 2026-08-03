# QM5_10582 Q08 recovery-lineage repair

Date: 2026-08-03

Scope: `QM5_10582_mql5-ema-pred`, `XAUUSD.DWX`, Q08 only

Code commit: `a03f4b1be` (`fix(q08): preserve recovery artifact lineage`)

## Outcome

PASS for the recovery-lineage contract. A fresh append-only Q08 work item,
`e196d30b-e4d4-40b6-961a-4e5391eae918`, was enqueued with byte-pinned
ablation and archived-report bindings. Revalidation of the stored payload
returned `lineage_valid=true` and `reason=hash_pins_match`. The work item was
still `pending` when this evidence was written, so this document makes no Q08
pipeline-verdict claim.

No historical work-item row was rewritten or reopened.

## Broken references and archive roots

The append-only recovery sweep had created retry row
`a342cac8-31b5-4d04-9663-1deb42fecfdc` without carrying the owner-authorized
artifact bindings from original requalification row
`95015420-11d0-4c11-bb98-25fa2a361048`. The retry therefore resolved its Q08.5
inputs beneath the new work-item identity, while the retained bytes remained
under roots associated with the old identity.

The two `.requeued_*` roots examined were:

- `D:\QM\reports\work_items\95015420-11d0-4c11-bb98-25fa2a361048.requeued_20260726T1741450000`
  - `aggregate.json`: 12,886 bytes, SHA-256 `ac80f7ff3a08a86afd991a89748028a50e0e1afcfc6d61b887239d6b7aa763af`
  - `8_5_neighborhood.json`: 237 bytes, SHA-256 `25e07ea1d0fe63870a0dd7979711d97801a37c982ba088e0e417e97b0b18d08e`
- `D:\QM\reports\work_items\95015420-11d0-4c11-bb98-25fa2a361048.requeued_20260727T0341290000`
  - `aggregate.json`: 12,886 bytes, SHA-256 `f6bba98de9e48f423379ab06b8d122ddc684417010565c6181ae7599cfb1aa68`
  - `8_5_neighborhood.json`: 237 bytes, SHA-256 `25e07ea1d0fe63870a0dd7979711d97801a37c982ba088e0e417e97b0b18d08e`

The authoritative redirect recorded by the owner requalification row is:

`D:\QM\reports\work_items\_requal_archive\95015420-11d0-4c11-bb98-25fa2a361048\exception_717bdea188c38290`

Its exact retained files are:

- `QM5_10582\Q08\XAUUSD_DWX\aggregate.json`: 12,886 bytes, SHA-256 `42feb4cff28643710464871583f8ebadcaa14134764b4f8fbabcad2a5ed68af6`
- `QM5_10582\Q08\XAUUSD_DWX\8_5_neighborhood.json`: 237 bytes, SHA-256 `25e07ea1d0fe63870a0dd7979711d97801a37c982ba088e0e417e97b0b18d08e`

That archive contains the prior aggregate and Q08.5 result, but not a reusable
`perturbations.json`. A fresh Q08.5 run must therefore create:

`D:\QM\reports\pipeline\QM5_10582\Q08\neighborhood\XAUUSD_DWX\perturbations.json`

The expected row-scoped aggregate path for the new row is:

`D:\QM\reports\work_items\e196d30b-e4d4-40b6-961a-4e5391eae918\QM5_10582\Q08\XAUUSD_DWX\aggregate.json`

## Contract repair

`tools/strategy_farm/q08_recovery_lineage.py` now builds and validates schema
`qm.q08-recovery-lineage/v1`. Recovery retries carrying an owner-authorized
Q08 requalification must carry:

- the retry and lineage-source work-item IDs;
- all three ablation setfiles as absolute paths, byte sizes, and raw-byte
  SHA-256 pins;
- the authoritative archived aggregate and Q08.5 result with the same pins;
- the fresh `perturbations.json` target; and
- `historical_rows_mutated=false`.

The enqueue sweep refuses malformed owner-authorized lineage instead of
downgrading it to an unbound generic retry. `farmctl` authenticates the stored
payload again before dispatch, writes a row-scoped manifest, and passes its
path and SHA-256 to the Q08 aggregate runner. The aggregate runner authenticates
the manifest and every bound artifact before tester work. Missing bytes,
changed bytes, wrong size, duplicate/missing roles, or a changed manifest all
fail closed.

The Q08.5 setfile materializer was also corrected to update only the parsed
effective assignment in canonical markerless setfiles. It keeps the base block
immutable and respects the parser's existing last-value-wins contract; this
removes the independent `override count got=2:need=1` failure that had prevented
fresh perturbation generation.

## New append-only row and pins

Fresh row: `e196d30b-e4d4-40b6-961a-4e5391eae918`

Retry source: `a342cac8-31b5-4d04-9663-1deb42fecfdc`

Lineage source: `95015420-11d0-4c11-bb98-25fa2a361048`

Passing Q07 predecessor: `ec6090aa-f087-4df7-9b01-8bef195b60e6`

Pinned ablations:

- `setfile_ablation_00`: `8d47c4cc8191e067af31920bceb3cdcb1af2ebea63b4ddb8df954b9a975cb4f3`
- `setfile_ablation_01`: `f2bf459a3255c09eaf4b2333d870eb1a7d06462132c18e0d85dc3a06ac73d5d6`
- `setfile_ablation_02`: `477bc9142a10fc09e590d32aad14e056af0710d520f35882525313e4babc6cf1`

Targeted dry-run and apply each selected exactly one Q08 retry:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_10582 --max-infra-attempts 100 --max-part2-per-run 5
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_10582 --max-infra-attempts 100 --max-part2-per-run 5 --apply
```

## Verification

Focused regression suite:

```text
109 passed in 6.88s
```

Coverage includes valid carry-forward, missing bytes, SHA mismatch, missing
roles, enqueue refusal, payload preservation, dispatcher validation, manifest
authentication, canonical markerless setfiles, and immutable base assignments.
`py_compile` also passed for every changed Python module.

The stored payload was read back from the farm database and rehashed against
disk through the production validator:

```json
{
  "work_item_id": "e196d30b-e4d4-40b6-961a-4e5391eae918",
  "lineage_valid": true,
  "reason": "hash_pins_match",
  "bindings": 3,
  "archived": 2
}
```

Append-only check at evidence time:

- original row `95015420-11d0-4c11-bb98-25fa2a361048`: `done/INFRA_FAIL`,
  `updated_at=2026-08-02T12:29:28+00:00`;
- prior retry `a342cac8-31b5-4d04-9663-1deb42fecfdc`: `done/INFRA_FAIL`,
  `updated_at=2026-08-02T14:42:38+00:00`;
- fresh row `e196d30b-e4d4-40b6-961a-4e5391eae918`: `pending`, created and
  updated at `2026-08-03T10:12:59+00:00`.

The queue owns execution. No terminal was started, stopped, or interrupted,
and no live or AutoTrading setting was touched.
