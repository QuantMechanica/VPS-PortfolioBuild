---
title: Canonical source-hash binding — helper, validator, and drift proof
task: 8628cddd-d8d3-4e9e-ae7b-c8d5cfea216d
created: 2026-08-24
author: Claude
status: NEW (append-only; does not modify any historical evidence/verdict)
---

# Canonical source-hash binding (router task 8628cddd)

## Defect class fixed

Evidence documents, setfile `build_hash` fields, and EA `build_identity` records
have historically declared a SHA-256 for a source file (`.mq5`, `.mqh`, `.set`)
by hashing the **raw working-copy bytes on disk** (legacy `_sha256_file()` in
`tools/strategy_farm/farmctl.py`, defined at two sites — line ~6227 and line
~12783; both are byte-identical duplicates that hash `path.open("rb")`). On this
Windows checkout, `core.autocrlf` / `.gitattributes` normalization means on-disk
bytes can be CRLF while the committed git blob is LF, so the declared hash binds
to nothing durable: it never matches `git show <ref>:<path> | sha256sum`. The
2026-08-24 verification sweep found ≥13 reworks with exactly this drift.

## What was built (prospective standard)

- Helper + validator: `tools/strategy_farm/canonical_hash.py`
  - `canonical_blob_sha256(path, ref="HEAD")` — SHA-256 of `git cat-file blob
    <ref>:<path>`, the `.gitattributes`-correct committed content (raw for
    `-text` files, LF for text files). This is the value tooling must RECORD.
  - `working_copy_sha256(path)` — the legacy on-disk basis, exposed for
    drift diagnostics only.
  - `validate_declared_hash(path, declared, ref="HEAD")` — fail-closed PASS/FAIL;
    flags the CRLF/working-copy-drift fingerprint (declared == on-disk bytes but
    != committed blob). Importable and runnable as a standalone CLI.
- Tests: `tools/strategy_farm/tests/test_canonical_hash.py` — 14 hermetic tests
  (temp git repos only; no live farm state touched). `14 passed`.
- Process doc: `processes/14-ea-enhancement-loop.md` — step 4 amended and a new
  "Source hashes bind to the committed blob, never working-copy bytes" section
  points rework/build sessions at the helper instead of ad-hoc
  `hashlib.sha256(open(path,'rb').read())`.

## Real drift-case proof

Target committed file (rework EA 39001, on this checkout at HEAD):
`framework/EAs/QM5_39001_forexfactory-trading-made-simple-tms/sets/QM5_39001_forexfactory-trading-made-simple-tms_EURUSD.DWX_H1_backtest.set`

`git ls-files --eol` reports `i/lf  w/crlf` — index is LF, working copy CRLF.

| basis | sha256 |
|---|---|
| naive working-copy (`_sha256_file` / `sha256sum` of on-disk bytes) | `434d54819162a676d0f540bcf3e221a4de269bc74389df700414cbc0b44f48fc` |
| canonical committed blob (`git cat-file blob HEAD:<path>`) | `c43bfbc57423c7fa6e6c11c7d41b3e3dca905583b7afb7cc79442c02b71252d1` |

Under the old naive approach, an evidence doc that declared `434d5481…` would
re-verify as PASS (it equals `_sha256_file(path)`), so the drift was invisible.
The new validator flags it:

```
$ python tools/strategy_farm/canonical_hash.py \
    framework/EAs/QM5_39001_.../..._EURUSD.DWX_H1_backtest.set \
    --declared 434d54819162a676d0f540bcf3e221a4de269bc74389df700414cbc0b44f48fc
FAIL: framework/EAs/QM5_39001_.../..._EURUSD.DWX_H1_backtest.set @ HEAD
  declared  434d54819162a676d0f540bcf3e221a4de269bc74389df700414cbc0b44f48fc
  canonical c43bfbc57423c7fa6e6c11c7d41b3e3dca905583b7afb7cc79442c02b71252d1
  workcopy  434d54819162a676d0f540bcf3e221a4de269bc74389df700414cbc0b44f48fc
  declared hash equals transient working-copy bytes, not the committed blob --
  classic CRLF/working-copy drift; rebind via canonical_blob_sha256()
(exit code 1)
```

Control: a `-text` (raw) setfile such as
`framework/EAs/QM5_20030_eia-cad/sets/QM5_20030_eia-cad_USDCAD.DWX_M5_backtest.set`
shows `i/lf w/lf attr/-text` and on-disk == blob (`0f0dc3e7…`) — no drift, because
`git cat-file blob` preserves its exact committed bytes. The helper therefore does
the correct per-`.gitattributes` thing without any manual line-ending handling.

## Scope / constraints honored

- Prospective only; no retroactive rebinding of the ~13 drifted reworks (separate
  task b4fe23af).
- No historical evidence/verdict edited — this is a new document.
- No `farmctl.py pump`/routing/backtest dispatch, no `terminal64.exe`, no
  AutoTrading. All tests run on temp fixtures, not the live state DB.
