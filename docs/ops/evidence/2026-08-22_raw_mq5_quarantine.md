# Raw web-MQ5 quarantine and direct-use refusal

Date: 2026-08-22  
Router task: `aa6510fb-71a4-4284-b056-8fdaac95e9a2` (`SP-D2`)  
Disposition: `IMPLEMENTED_REVIEW_REQUIRED`

## Outcome

All three named raw MQ5 sources are registered as `RAW_UNTRUSTED` and
`DO_NOT_DEPLOY` in both the committed quarantine source ledger and the live
Strategy Farm source ledger:

| source | farm source id | runtime ledger state | locator |
|---|---|---|---|
| Prop Challenger EA | `da09056d-06ee-5de9-82d1-80bce158e5b8` | `blocked`, lane `legacy` | `G:\**\Prop Challenger EA.mq5` |
| King Trader EA | `1cff74d9-a626-512c-b7a1-7cc53d9a2753` | `blocked`, lane `legacy` | `G:\**\King Trader EA.mq5` |
| TickTrader2 | `4c126ff4-67b8-5a28-bac9-1da744810271` | `blocked`, lane `legacy` | `G:\**\TickTrader2.mq5` |

The runtime rows were created through `farmctl add-source` as
`local_archive`, then immediately moved from `pending` to `blocked` through
`farmctl set-source-status`; each row points back to this evidence document.
They therefore cannot be claimed by the research miner as ordinary pending
sources.

The `G:` volume is not mounted in this headless scheduled-task environment.
No raw source was opened, copied, executed, or hashed. The committed ledger
records that fact explicitly as `UNAVAILABLE_G_DRIVE_UNMOUNTED` rather than
inventing byte identity. Its schema accepts a real SHA-256 later, allowing the
same guard to reject byte-identical renames once an authorized intake process
captures hashes.

## Technical refusal chain

`tools/strategy_farm/raw_mq5_quarantine.py` validates the committed ledger
fail-closed and refuses:

- every direct compile or promotion path on `G:`;
- every source with one of the three quarantined basenames, even after copying
  it into another directory;
- every byte-identical source whose SHA-256 is later populated in the ledger;
- non-canonical compile/promotion paths at the compile boundary; and
- a missing or malformed quarantine ledger.

The guard is applied at three independent advancement boundaries:

1. `framework/scripts/compile_one.ps1` checks the caller-supplied path before
   `Resolve-Path`, MetaEditor discovery, include mirroring, or output creation,
   then checks the resolved MQ5 again.
2. Gemini build review dispatch checks `mq5_path` before it can mint the
   mandatory Codex review task.
3. `farmctl record-build` checks promotion provenance before SPEC/entry review
   and before Q02 auto-enqueue; refusal records a durable
   `raw_mq5_quarantine_refused` build block and creates no work items.

The only permitted re-entry contract in every ledger row is
`NEW_CARD_V5_REIMPLEMENT_FULL_GATE_CHAIN`: a new Strategy Card, a fresh V5
reimplementation, and the complete gate chain. A raw file is never an EA build
or deploy candidate.

## Verification

- Quarantine unit/integration suite: `7 passed`.
  - proves 3/3 exact ledger registrations and policy fields;
  - proves nonexistent `G:` paths fail before filesystem access;
  - proves a copied quarantined basename fails while a distinct canonical
    `QM5_...` V5 fixture passes;
  - invokes `compile_one.ps1` against `G:\...\TickTrader2.mq5` and observes
    `RAW_MQ5_GDRIVE_DIRECT_USE_REFUSED` without MetaEditor discovery;
  - proves Gemini REVIEW dispatch refuses; and
  - proves `record-build` becomes `blocked` with zero Q02 work items.
- Existing agent-router suite: `29 passed`.
- Focused existing build-record/factory-off/basket suite: `10 passed,
  20 deselected`.
- Existing PowerShell compile-one structural test:
  `PASS Test-CompileOneIncludeTargets`.
- `python -m py_compile` and `git diff --check`: PASS.

No terminal, MetaEditor, backtest, deployment, `T_Live`, AutoTrading, live
setfile, live weight, magic registry, EA source, or binary was changed or
started.

## Files in review

- `framework/registry/raw_mq5_source_ledger.csv`
- `tools/strategy_farm/raw_mq5_quarantine.py`
- `framework/scripts/compile_one.ps1`
- `tools/strategy_farm/agent_router.py`
- `tools/strategy_farm/farmctl.py`
- `tools/strategy_farm/tests/test_raw_mq5_quarantine.py`
- `tools/strategy_farm/tests/test_factory_off_build_interlock.py`
- `docs/ops/evidence/2026-08-22_raw_mq5_quarantine.md`

## Verdict

`IMPLEMENTED_REVIEW_REQUIRED`: 3/3 raw MQ5 sources are durably quarantined and
direct compile/review/pipeline promotion from `G:` is mechanically rejected.
Leave in REVIEW; this is not approval to inspect, reimplement, compile, or
deploy any raw source.
