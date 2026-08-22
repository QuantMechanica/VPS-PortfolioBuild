# SP-A3 — per-source observability TTL and cross-surface identity

Date: 2026-08-22  
Router task: `9a91fe9d-92a2-4528-a699-7eb2c5551de7`  
Branch: `agents/board-advisor`  
Verdict: `IMPLEMENTED_FOR_REVIEW`

## Dependency and scope

- SP-A1 is APPROVED (`bf2212920`): the runtime pointer supplies the manifest,
  expected sleeve roster, account/server/phase binding, and deterministic
  identity hashes.
- SP-A2 is APPROVED (`1a2149ef7`): Live Pulse is already bound to that pointer.
- SP-A3 adds observation metadata only. It does not change an EA, deployment,
  pipeline, or Live Pulse trading verdict. `live_book_pulse.verdict` is computed
  before the new block and the attachment helper has a regression assertion
  proving the value remains unchanged.
- No terminal was started, stopped, probed, or reconfigured during this work.
  No AutoTrading/T_Live action occurred.

## Implemented contract

`tools/strategy_farm/live_observability_contract.py` defines
`qm.live_observability.v1`. Live Pulse produces the block; Morning Brief and
Mission Control read that producer block and re-evaluate the original timestamps
against their observation time. A consumer's own newly-written envelope time is
never substituted for a source timestamp.

Every source record carries the required fields:

- `source_generated_at_utc`
- `observed_at_utc`
- `max_age_sec`

It additionally exposes `age_sec`, `freshness`, source fingerprint, timestamp
basis, source path, and any fail-closed error. The contract covers:

| Source | Source timestamp | TTL |
|---|---|---:|
| deploy pointer | `written_at_utc` | 90 days |
| manifest | `generated_at_utc` / `generated_at` | 90 days |
| live pulse | `generated_at_utc` | 45 minutes (30-minute producer cadence plus margin) |
| DD guard | `last_run_utc` | 10 minutes (two scheduled cadences) |
| account snapshot observed by DD guard | `equity_observed_at_utc` | 180 seconds (guard input contract) |

The aggregate is `GREEN` only if every source is `FRESH` and all four identity
axes are present. An exceeded TTL produces `STALE`; missing/malformed time or
identity produces `UNKNOWN`.

## Cross-surface identity

The producer block carries these four stable SHA-256 axes:

- `manifest_sha256`: actual manifest bytes;
- `sleeve_sha256`: SP-A1 expected-roster identity;
- `account_sha256`: expected account/server/phase plus Pulse/DD-guard observed
  account binding;
- `state_sha256`: pointer, manifest, Pulse state projection, DD-guard, account
  snapshot, and their producer timestamps.

Morning Brief returns the unchanged producer axes in `live_fingerprints` and
the full block in `observability_contract`. Mission Control returns the same
block in `live_observability`. Consumers may re-age the sources, but do not
mint new identity hashes.

## DD-guard latency visibility

The contract exposes both:

- `dd_guard_to_account_snapshot_sec`
- `surface_to_dd_guard_sec`

and `dd_guard_gap_visible`. A read-only dry evaluation of the runtime D:-state
at `2026-08-22T11:54:15Z` produced:

| Source | Age | TTL | Classification |
|---|---:|---:|---|
| Live Pulse | 1,453 s | 2,700 s | FRESH |
| DD guard | 231 s | 600 s | FRESH |
| DD-guard account snapshot | 236 s | 180 s | STALE |

The resulting observation status was `STALE` even though the Pulse envelope and
DD-guard run were themselves fresh. This is the previously-hidden latency gap;
it is now visible rather than masked by an aggregator write time. The dry read
did not write the runtime Pulse file.

Runtime fingerprints observed in that dry evaluation:

- manifest: `8c719b080e18d30d83432f0999d694f699f2859cef72c0ce7738631fb084eab6`
- sleeves: `9aa10411d99adf81861503a0023832874873de39eeaacfa880bfc4368fcf84d0`
- account: `4c03c8360ccb9e476013e12966829f941757cce5d83bf9aeb68904acfce060de`
- state: `817bf1d63b1a16bd1ba9a8f5efc5f7df9370effbfb9df36ca7e4e0256eb93405`

## Atomic-write guarantee

- Live Pulse retains its existing same-directory temporary-file replacement.
- Mission Control now writes its JSON through a same-directory PID-scoped
  temporary file followed by `os.replace`; its test verifies a complete JSON
  document and no leftover temp file.

## Focused verification

Command:

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_live_observability_contract.py \
  tools/strategy_farm/tests/test_live_book_pulse.py \
  tools/strategy_farm/tests/test_morning_brief_live_status.py \
  tools/strategy_farm/tests/test_mission_control_v2_data.py
```

Result: `90 passed in 2.83s`.

The hostile fixture forcibly changes only the stored aggregate status to
`GREEN` while keeping a 901-second-old DD-guard source. Each consumer re-ages
the source and returns `STALE`; the fresh wrapper cannot override it. The
cross-surface fixture also asserts byte-identical values for all four
fingerprints across Live Pulse, Morning Brief, and Mission Control and verifies
the explicit DD-guard latency fields.

Additional checks:

- `python -m py_compile` for all four production Python modules: PASS.
- targeted `git diff --check`: PASS (line-ending notices only; unrelated dirty
  factory files were excluded from the explicit pathspec).
