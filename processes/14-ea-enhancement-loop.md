---
title: EA Enhancement and Repair Loop
owner: OWNER
last-updated: 2026-07-22
---

# 14 — EA Enhancement and Repair Loop

This loop distinguishes implementation repair from strategy-mechanics change and
prevents untracked `_vN` proliferation.

## Classification

- **Implementation defect:** code, serialization, timing, data plumbing, sizing,
  deployment, or diagnostics fail to implement the approved card. Repair is allowed
  in the current unqualified build, with new hashes and rerun evidence.
- **Strategy enhancement:** economic entry, exit, sizing, session, filter, or
  portfolio mechanics change. Create a new version and rerun every required phase.
- **Infrastructure defect:** repair the runner/data/environment; do not version the
  strategy or issue a strategy verdict.

## Steps

1. Cite the failing artifact-bound evidence and classify the change.
2. Record the exact card clauses and code paths affected.
3. Implement the smallest deterministic change; never loosen rules merely to
   improve a metric or force trades.
4. Compile, validate registries/setfiles/deployment hashes, and rerun from the
   earliest invalidated phase. When you record or verify a **source-file** hash
   (`.mq5`, `.mqh`, `.set`) in an evidence document, setfile `build_hash` field,
   or `build_identity` record, compute it from the canonical committed blob, not
   from working-copy bytes — see "Source hashes bind to the committed blob" below.
5. Compare old and new evidence, including trade-count, cost, drawdown, and
   behavior changes.
6. Retain failed versions and conclude with recovered, falsified, or blocked.

OWNER decides ambiguous card-mechanics changes and whether a non-converging line of
versions should continue. T6/live requires a new exact-artifact promotion decision.

## Compile is governed, never ad hoc

Step 4's "Compile" means the governed path only: the scoped `build_check.ps1`
wrapper, or `farmctl.py enqueue-compile` into the `COMPILE_EA` queue. If the
governed wrapper fails closed with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`
(factory terminals are live), **do not** reach for an idle MetaEditor, a
disposable profile, a worker-adjacent terminal, or any other side channel to
produce a fresh `.ex5` anyway. Wait for an idle window or enqueue the
governed `COMPILE_EA` work item and let the fleet compile it. A `.ex5` built
outside the governed path and committed anyway is a Hard-Rule (ROT)
violation regardless of how clean the accompanying source repair is — see
`docs/ops/evidence/2026-08-24_rot_remediation_39001_38001_exrevert.md` for
the incident and remediation, and
`tools/strategy_farm/validate_ex5_commit_guard.py` (installed as the shared
`pre-commit` hook in `.git/hooks/`, applies to every worktree) for the
fail-closed guard that now refuses any staged `framework/EAs/**/*.ex5`
change lacking a matching `COMPILE_EA` receipt (`status=done`,
`verdict=COMPILE_OK`, hash-bound to both the `.ex5` and its `.mq5`).

## Source hashes bind to the committed blob, never working-copy bytes

Recurring defect class (first diagnosed 2026-08-17 "Pin-SHA über LF-Blob-Bytes"
/ "Bindung nutzt Arbeitskopie-Bytes"; re-confirmed by the 2026-08-24 sweep with
≥13 drifted reworks): a rework session declares a SHA-256 for a source file by
hashing the **raw working-copy bytes on disk** (the legacy `_sha256_file()` /
`hashlib.sha256(open(path,'rb').read())` pattern). On this Windows checkout,
`core.autocrlf` and `.gitattributes` normalization mean the on-disk bytes can be
CRLF while the committed git blob is LF, so the declared hash binds to **nothing
durable** — it never matches `git show <ref>:<path> | sha256sum`. This does not
apply to `.ex5` (binary, no line-ending drift), but it silently corrupts every
declared `.mq5`/`.mqh`/`.set` source hash.

**Rule (prospective):** any source-file hash you record or re-verify during a
rework must come from the canonical committed blob, i.e.
`git cat-file blob <ref>:<path>` (which git already normalizes correctly per
`.gitattributes` — raw for `-text` files, LF for text files). Do **not** write
ad-hoc `hashlib.sha256(open(path,'rb').read())` for this. Use the shared helper:

```
python tools/strategy_farm/canonical_hash.py <path> --declared <sha256>
# exit 0 = PASS (binds to committed blob), 1 = FAIL (drift), 2 = usage/error
```

Or, from tooling, import it:

```python
from tools.strategy_farm.canonical_hash import (
    canonical_blob_sha256,   # the value to RECORD
    validate_declared_hash,  # fail-closed PASS/FAIL check for a declared hash
)
```

`validate_declared_hash` is fail-closed: an untracked path or git failure is a
FAIL, and it flags the specific CRLF/working-copy-drift fingerprint (declared
equals on-disk bytes but not the committed blob). Run it as a close-out check
before recording rework evidence. This standard is prospective only —
retroactive rebinding of the known-drifted historical reworks is a separate task.
