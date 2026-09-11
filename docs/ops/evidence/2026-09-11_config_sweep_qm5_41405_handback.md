# QM5_41405 declared configuration sweep — hand-back

Router task: `036de7b9-baa1-4dc8-aa02-46e68d3e2331`.

## Delivered

`tools/strategy_farm/config_sweep.py` implements a declaration-bound generic
`qm.window-sweep.v1` adapter for non-live configuration programs. It validates
the approved-card commit, MQ5/EX5/base-set hashes, risk/news hard limits,
matrix binding, deterministic UUID5 cells, and setfile minimal-diff rendering.
The worker now dispatches explicitly marked `sweep_engine=config_sweep` rows to
that authenticator; unknown engines continue to fail closed.

The declared QM5_41405 program is
`WINSWEEP_QM5_41405_USDJPY_DWX_2019_2025`, bound to card commit
`5136355a4aba84db5e5387ffe5ee4aef1e05c4b6`, the compiled MQ5/EX5 hashes, the
canonical fixed-risk setfile, and the immutable 50-config/350-cell matrix in
`2026-09-11_config_sweep_qm5_41405_declaration.json`.

Focused verification passed:

```text
python -m pytest tools/strategy_farm/tests/test_config_sweep.py tools/strategy_farm/tests/test_research_canary.py -q
12 passed
python -m py_compile tools/strategy_farm/config_sweep.py tools/strategy_farm/terminal_worker.py
PASS
```

The non-mutating control plan and enqueue preview both returned exactly seven
new deterministic control rows. No factory row, setfile, or artifact directory
was written.

## Required next action

The production `--apply` path intentionally calls `require_current_workers()`.
Because `terminal_worker.py` changed, the orchestrator must perform its
staggered worker reload before the seven control rows can be inserted and
claimed. This is a fail-closed rollout requirement, not a queue failure.
After reload, apply the seven controls, wait for a real claim, compare their
four identity fields to the WINSWEEP stage-A controls, and only then enqueue
the remaining 343 rows.

**RESULT (Q-only):** Q-CONFIG-SWEEP is REVIEW. Tooling and declaration PASS;
the required worker rollout means no control row, claim, identity result, or
350-cell enqueue is claimed yet.
