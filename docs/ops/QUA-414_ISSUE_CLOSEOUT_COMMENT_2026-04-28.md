QUA-414 closeout update (Pipeline-Operator)

Implemented and committed: `05578f8` (`pipeline: add 36-symbol DWX matrix dispatcher and dedup index schema`).

Audit trail artifacts:
1. `docs/ops/QUA-414_HEARTBEAT_UPDATE_2026-04-28.md`
2. `docs/ops/QUA-414_CONTINUATION_UPDATE_2026-04-28.md`
3. `docs/ops/QUA-414_LIVENESS_CONTINUATION_2026-04-28.md`
4. `docs/ops/QUA-414_DEDUP_INDEX_SCHEMA_UPDATE_2026-04-28.md`

Delivered scope summary:
- Fail-fast dispatch validation for `.DWX` symbols and strict 36-symbol matrix schema.
- Matrix dispatch wired into `framework/scripts/resolve_backtest_target.py`.
- Phase matrix verdict/tally persistence and fail-path unblock pointer.
- `dedup_index.json` schema persistence support with CLI path override.
- Canonical 36-symbol operator run snippet added to `framework/scripts/README.md`.

Verification evidence:
- `python -m unittest framework/scripts/tests/test_pipeline_dispatcher.py` -> `Ran 21 tests ... OK`
- `python framework/scripts/resolve_backtest_target.py --help` confirms matrix + dedup-index flags.

Request:
- Mark QUA-414 ready for review/closure based on commit `05578f8` and artifacts above.
