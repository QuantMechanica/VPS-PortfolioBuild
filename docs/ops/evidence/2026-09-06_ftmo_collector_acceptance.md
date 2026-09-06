# FTMO collector acceptance — REVIEW, native acceptance incomplete

Router task: `3a1eba6c-b4ad-48f5-a12b-42eb4b4ca528`. 2026-09-06.
Implementation: `C:/QM/worktrees/codex-ftmo-collector-acceptance-20260906`, branch `agents/codex-ftmo-collector-acceptance-20260906`, commit `894bb52b03`.

## Findings and hardening

The delivered collector had optional identity binding, second-resolution session identity, shared-write append access, unchecked writes and successful initialization even when its first append failed. Hardened with required login/server, demo-only execution outside the tester, narrower append sharing, write-count checks, first-sample initialization failure, output traversal checks and session identity including chart and microsecond counters. This reduces same-second collision risk; native restart and simultaneous-instance acceptance are still required. A continuously exclusive writer lock is not yet implemented, so the installation contract remains exactly one collector instance.

The reader previously sorted capture order, mixed trials/accounts, ignored epoch disagreement and sequence holes, omitted missing M5 buckets from continuity reporting, and could mark a day EVALUABLE despite a large hole. It now rejects these identity/cadence defects, preserves same-second endpoint capture order, lists missing intervals, and marks affected days ABSTAIN_GAPS. Daily compaction refuses gaps and existing destinations, binds the immutable source hash, writes daily M5 JSONL and publishes a manifest last. Verification detects source/output tampering and unexpected files. Partial boundary days remain ABSTAIN_PARTIAL_DAY.

## Verification and limits

`python -m pytest -q tools/strategy_farm/tests/test_ftmo_trial_telemetry.py`: **14 passed**. `git diff --check`: clean.

The retained **synthetic Python fixture**, `2026-09-06_ftmo_collector_acceptance/synthetic_raw.jsonl`, has 901 one-second samples, one simulated session restart, a Prague summer-midnight crossing and a planted 94,000 interval minimum. Compaction produces four M5 buckets over two Prague dates; all daily manifest hashes verified. Reproduce with the isolated branch module using `--input <fixture> --output <report.json> --compact-directory <new-directory>`; `verify_compaction` verifies an existing directory. The fixture is not native MT5 tester output and proves only reader/compactor behavior.

Canonical `include_mirror.py guard` returned **LIVE_FACTORY_AD_HOC_COMPILE_REFUSED**, retained in `2026-09-06_ftmo_collector_acceptance/compile_preflight.json`. Active terminal processes require a claimed governed compile work item. The current queue's `compile_work_items.py:3167` resolves candidates under `framework/EAs/<label>`; this monitor lives under `framework/monitor` and has no governed monitor-probe candidate. No registry row or active EA was invented to bypass that boundary. No terminal was started, stopped, installed or reconfigured. Native compile and tester acceptance are **NOT RUN**, so the collector is **NOT ACCEPTED / NOT INSTALLABLE**. The ordinary tester TimeGMT behavior also needs a broker-offset-aware harness before its timestamps can certify Prague midnight.

## Concrete non-live installation and acceptance plan

Planned new directory: `C:/QM/mt5/T_FTMO_TrialCapture_20260906/` (not created). Do not reuse T_Live or an existing FTMO trading profile. OWNER/operator records the dedicated demo login/server, terminal data directory, trial ID and authorization. After a reviewed governed monitor compile/test path exists, compile the isolated source and its governed include; preserve source, include, binary and compiler-log SHA-256.

Native acceptance must run an instrumented tester harness with explicit simulated UTC, a restart at an M5 interior boundary, winter/summer Prague-midnight crossings, nonzero position/pending census and a planted intrainterval trough. Preserve raw tester bytes and journals, verify sequence/session continuity and every expected bucket, then inject a >10-second outage and require FAIL_GAPS. Never interpolate observations across downtime. A terminal-off interval cannot yield observed equity minima; a real restart with an excessive hole invalidates the window.

OWNER-facing checklist before any future installation:

- Governed native compile passes and native tester evidence passes the above cases; concurrent writer refusal is proven.
- Dedicated demo directory/login/server and unique output directory are recorded; exactly one collector instance.
- Trial profile, news binding and separately generated sets are reviewed; capture-only trial authorization does not authorize production trading.
- Copy approved artifacts only through the dedicated trial procedure. Verify the first INIT row, account identity, timer cadence and complete inventories.
- Snapshot raw files without modification, compact to fresh directories, verify manifest hashes, retain partial/gap abstentions and preregister acceptance limits.

This evidence requests review of source hardening and identifies the remaining infrastructure dependency. It asserts no pipeline, trial, installation or deployment PASS.
