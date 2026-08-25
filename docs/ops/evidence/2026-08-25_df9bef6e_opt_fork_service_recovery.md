# Q12–Q14 optimization-fork service recovery — 2026-08-25

Task: `df9bef6e-d7a8-4287-a50e-ecce080f6c10`  
Branch: `agents/board-advisor`  
Scope: make the three v4 optimization-fork admissions executable without
changing DL-089 selection rules, gate criteria, terminal workers, or live state.

## Result

PASS. The three commissioned pairs completed the manifest-native Q12 → Q13 →
Q14 chain. All three were explicit no-change audits: no filter search was
declared, the payload authorized zero selected filters, the parameter contract
declared zero parameters and zero trials, and therefore no challenger existed.
The terminal outcome is `KEEP_INCUMBENT`; it is not an optimized-winner claim.

| EA / symbol | Q12 | Q13 | Q14 |
|---|---|---|---|
| `QM5_10706 / GBPUSD.DWX` | `48c41285…` — `NO_FILTER_CHANGE` | `e1e86d92…` — `NO_PARAMETER_CHANGE` | `b5e18759…` — `KEEP_INCUMBENT` |
| `QM5_11421 / EURUSD.DWX` | `2a2bf134…` — `NO_FILTER_CHANGE` | `cc00fccc…` — `NO_PARAMETER_CHANGE` | `a42f2a71…` — `KEEP_INCUMBENT` |
| `QM5_11422 / USDCAD.DWX` | `09c21c5c…` — `NO_FILTER_CHANGE` | `b1ce8e01…` — `NO_PARAMETER_CHANGE` | `3078ad67…` — `KEEP_INCUMBENT` |

Final read-only census at `2026-08-25T19:03:06Z`: nine rows are
`done`, all carry `gate_contract_version=v4` and a durable receipt under
`D:/QM/reports/optimization_fork/<work_item_id>/receipt.json`; open managed
Q12/Q13/Q14 rows for these three pairs = **0**.

## Root cause

The fork router intentionally creates `kind=analytic` rows, while T1–T10 claim
only terminal work. The router's contract states that it routes successors but
does not adjudicate a gate. No governed analytic consumer existed, so the three
`activation_state=READY` Q12 rows had no holds and no possible claimant.

Two archival facts also blocked a naïve executor:

- The Q10 aggregates for `QM5_11421` and `QM5_11422` had been losslessly
  compressed to `.json.gz`; their original payload paths no longer existed.
- The current `QM5_10706` Q10 setfile hash was
  `b458a1b3…`, while the immutable admission bound `275e66e9…`. Git commit
  `aa6839ce…`, blob `a23f241b…`, reproduces the exact bound bytes under the
  repository's CRLF checkout policy.

The repair authenticates archived content by the original uncompressed/content
SHA-256 and size. It never restores, rewrites, or substitutes evidence.

## Implementation

- `0b69f8c95` adds the bounded analytic no-change service, CLI surface, pump
  stage, and tests.
- `ce0ebfd6a` lets the manifest router consume a gzip sibling or Git-history
  object only when its recovered bytes exactly match the immutable binding.
- `e33e5c14d` and `459746535` apply the farm's existing fresh-connection SQLite
  retry policy to routing and service writes.

The service is deliberately narrow and fail-closed:

- active holds, malformed payloads, manifest/version mismatches, missing
  bindings, or hash drift remain pending;
- any declared pattern candidates or selection results remain pending for the
  governed DL-089 selector;
- any nonzero/new parameter sweep remains pending for the development runner;
- Q14 auto-returns `KEEP_INCUMBENT` only when its authenticated Q12 and Q13
  ancestors are both no-change outcomes;
- existing terminal rows/verdicts are never updated.

No DL-089 threshold, frequency floor, selection rule, trial count, or gate
outcome vocabulary changed. No MT5 terminal, T_Live, or AutoTrading action was
performed.

## Live append-only trace

The exact-pair router was called separately for the three pairs; no bulk
admission was used. Q13 IDs appended:

```text
e1e86d92-52c6-519b-b628-b865309c42c5  QM5_10706 / GBPUSD.DWX
cc00fccc-1bdd-5706-8634-a5b06cc079b0  QM5_11421 / EURUSD.DWX
b1ce8e01-5c2a-5f91-a03d-46a730baf4b9  QM5_11422 / USDCAD.DWX
```

Q14 IDs appended:

```text
b5e18759-1377-5af7-9634-9f66bd293d0c  QM5_10706 / GBPUSD.DWX
a42f2a71-ed1c-538a-b97a-142a67b907f2  QM5_11421 / EURUSD.DWX
3078ad67-9a19-56cb-a252-0a112596343a  QM5_11422 / USDCAD.DWX
```

Each transition was a compare-and-set from `pending/verdict=NULL`; predecessor
rows and all historical v3/cutover rows remain intact.

## Verification

```text
python -m py_compile tools/strategy_farm/optimization_fork_service.py \
  tools/strategy_farm/optimization_fork_driver.py \
  tools/strategy_farm/farmctl.py
PASS

python -m pytest -q \
  tools/strategy_farm/tests/test_optimization_fork_service.py \
  tools/strategy_farm/tests/test_optimization_fork_driver.py \
  tools/strategy_farm/tests/test_v4_runtime_wiring.py
22 passed

focused service + driver rerun after contention fix
10 passed

git diff --check -- <touched paths>
PASS
```

The final database query returned all nine expected IDs as `done` with the
verdicts shown above and `open_managed_rows=0` for the three commissioned pairs.
