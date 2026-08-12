# DXZ Truth-Chain Evidence Tool

`tools/strategy_farm/dxz_truth_chain.py` reconciles a manifest-defined Darwinex
Zero book against the read-only `T_Live` terminal and creates a new immutable
evidence directory. It never writes below `--live-root` and refuses an output
path there. Existing bundle directories are never overwritten.

## Schema-v2 qualification boundary (2026-07-16)

Truth Chain accepts a qualification source only when it is a schema-v2
`AS_LIVE_REQUAL` result. Discovery mode, schema-v1 results, uncertified costs,
empty or circular identity/outcome evidence, incomplete real-tick history
metrics, and unstable start/end artifact hashes all fail closed. The selected
frozen reference path and stream hash, requested/effective time window, cost
evidence and any explicit override manifest must remain bound through the
candidate and adjudication chain.

For costs, “bound” means all five semantic axis artifacts, not a copied PASS
flag. Truth Chain independently reloads the original structured JSON evidence,
checks the axis-specific evidence-type allowlist and fixed conservative
thresholds, verifies source-manifest/sleeve/timeframe/window/validity coverage,
and requires identical artifact plus sidecar hashes at sweep start, sweep end
and truth inspection. A `GLOBAL` artifact must enumerate every covered identity
on every axis. Missing or expired current spread/swap evidence, dummy JSON,
wrong-axis reuse, changed sidecars and freely lowered stress thresholds fail
the candidate qualification chain.

The chain also retains the source-manifest `set_file_expectation` comparison.
For the absolute-risk DXZ contract, `RISK_PERCENT` must match manifest sleeve
risk and the live preset while `PORTFOLIO_WEIGHT` is exactly 1. This prevents a
second portfolio multiplier from silently downscaling risk after the runner's
preflight.

## Canonical invocation for the isolated truth sandboxes

```powershell
python tools\strategy_farm\dxz_truth_chain.py `
  --manifest D:\QM\reports\portfolio\portfolio_manifest_sunday_23sleeve_DRAFT_20260711.json `
  --sandbox-root C:\QM\mt5\DXZ_Truth_1 `
  --sandbox-root C:\QM\mt5\DXZ_Truth_2 `
  --sandbox-root C:\QM\mt5\DXZ_Truth_3 `
  --sandbox-root C:\QM\mt5\DXZ_Truth_4 `
  --live-preset-tag dxz23_live `
  --output-dir D:\QM\reports\portfolio\dxz_truth_chain_23_<UTC> `
  --quiet
```

Each `--sandbox-root` contributes its tester history and platform include tree.
The bundle reports missing symbols and content-hash drift across sandboxes.

## Required qualification bindings

Paths are hashed for diagnosis, but paths alone do not prove historical test
identity. A sleeve becomes `CLOSED` only when its manifest binds these full
SHA-256 values:

- `qualified_ex5_sha256`
- `qualified_set_sha256`
- `qualified_stream_sha256`
- `qualified_live_preset_sha256`

The same keys may be placed inside a per-sleeve `qualification` or
`artifact_bindings` object. The live EX5 must equal `qualified_ex5_sha256`.
Without the declarations the sleeve is `UNBOUND`, even if today's repo EX5 and
live EX5 happen to match.

Optional manifest fields include `strategy_card`, `mq5_path`,
`qualified_ex5_path`, `qualified_set_path`, `qualified_stream_path`,
`live_ex5_path`, `live_preset_path`, and `history_symbols`. Existing fields
`ex5_path`, `backtest_set`, `q08_stream`, `trades`, `magic_number`, and
`set_file_expectation` remain supported.

## Bound candidate enforcement

When the manifest is an adjudicator-produced `dxz_bound_candidate_book`, path
and sleeve hashes are not enough. Truth Chain additionally verifies all of the
following before it can return `PASS`:

- candidate status is exactly `BOUND_CANDIDATE_COMPLETE` and its embedded
  payload hash is valid;
- every sleeve has bound-pass qualification, explicit `artifact_bindings`, and
  a trade count;
- `source_requalification` resolves to the exact hashed schema-v2 summary whose
  embedded state is `qualification_mode=AS_LIVE_REQUAL`, `scope=FULL`,
  `status=PASS`, with certified costs, bound history/window/reference evidence,
  and all source jobs passing;
- `source_adjudication` resolves to the exact hashed adjudication artifact,
  whose embedded verdict is `PASS` and whose candidate contract is complete;
- adjudication and candidate bind the same requalification summary.

The resulting `qualification_chain` records the actual artifact SHA-256 for the
candidate, adjudication, and requal summary. Partial, incomplete, repaired, or
tampered evidence produces `FAIL`; it cannot be converted into freeze
eligibility by a gate-level PASS flag.

## Evidence contents

- `truth_chain.json`: Card, MQ5, recursive include tree, qualified/current EX5,
  backtest SET, live preset, q08 stream, cost model and `.DWX` history hashes;
  stream counts/date range/net; history coverage; all comparisons and issues.
- `input_manifest.json`: byte-for-byte manifest snapshot.
- `SHA256SUMS`: hashes of both evidence files.

Exit codes are `0=PASS`, `1=UNBOUND`, `2=FAIL`. A FAIL bundle is intentionally
still written: it is the evidence of the mismatch.

## Live pulse

`tools/strategy_farm/live_book_pulse.py --book-manifest <manifest>` now derives
the expected sleeve count and EA/symbol/magic/timeframe set from the manifest.
When archived preset files share a magic, it records the ambiguity and selects
the newest matching candidate unless the manifest pins `live_preset_path`.
The pulse remains read-only below `T_Live`.
