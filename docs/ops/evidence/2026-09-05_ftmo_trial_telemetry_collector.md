# FTMO trial telemetry collector

**Router task:** `79772247-80e1-4a26-b12b-6a7b4c6fc274`  
**Result:** `PASS_BUILD_ONLY`  
**Scope:** demo/Free-Trial instrumentation and offline reading only. No account creation, candidate EA recompile, T_Live change, process start, AutoTrading toggle, pointer signature, or trading authority.

## Delivered contract

`framework/monitor/QM_FTMO_TrialTelemetry.mq5` is a read-only account sampler intended only for an OWNER-created demo/Free-Trial terminal. It contains no trading library and no order/position mutation call. It samples on every terminal tick and on a bounded 1–5 second timer, appending one JSON object per observation to:

`<trial terminal>/MQL5/Files/<InpOutputDir>/trial_telemetry_raw.jsonl`

Each `qm.ftmo-trial-telemetry.raw/v1` row carries:

- explicit `trial_id`, restart-unique `session_id`, monotone per-session `sequence`, UTC time and epoch;
- Europe/Prague day key, using the same EU-DST implementation as `QM_FTMOGovernorPolicy.mqh`;
- account balance and `ACCOUNT_EQUITY` (therefore open P&L, accrued swap, and charged commissions as represented by the broker account);
- reconciled total positions and pending orders;
- the complete current position and pending-order inventories with magic, ticket, symbol and volume; position rows also carry floating profit and swap;
- source (`INIT`, `TICK`, `TIMER`, `DEINIT`) and account identity.

The raw log is append-only. A restart creates a new session rather than overwriting or reusing a sequence. MQL5 serializes chart events; an in-process busy latch prevents re-entry. Downstream identity is `(session_id, sequence)`: exact duplicate rows are idempotently ignored, while different bytes under the same identity fail as `identity_race_conflict`.

`tools/strategy_farm/portfolio/ftmo_trial_telemetry.py` validates the stream and emits `qm.ftmo-trial-telemetry.m5/v1`:

- M5 endpoint equity/balance and minimum equity across **all observed tick/timer samples** in each interval;
- endpoint position and pending-order counts by magic;
- restart count and explicit continuity gaps;
- per-Prague-day anchor balance, observed minimum equity, 5% daily floor and strict-below breach result;
- strict-above 10% target detection plus the exact flat-at-target position/order census.

The reader fails closed on duplicate JSON keys, invalid UTC or Prague keys, non-finite money, inventory disagreement, sequence regression, identity races, and unreconciled samples. Any sample gap beyond the configured ceiling makes continuity `FAIL_GAPS`; the first/last partial Prague day remains `ABSTAIN_PARTIAL_DAY`. `challenge_proof` is always false: a clean historical trial is screening evidence, never proof of a future outcome.

The interval-minimum basis is deliberately named `MINIMUM_OF_ALL_TICK_AND_TIMER_SAMPLES_IN_INTERVAL`. It is complete for terminal-observed account changes only while the collector is continuously armed; it is not relabelled as an exchange-tick proof. The simultaneous tick hook and ≤5-second timer eliminate the former 30-minute pulse blind spot, while the continuity gate exposes restart/network holes instead of interpolating them.

## Tester-generated dry run

Output: `D:/QM/reports/portfolio/ftmo_trial_telemetry_dryrun_20260905_055307/`

| artifact | rows | SHA-256 |
|---|---:|---|
| `tester_generated_raw.jsonl` | 2,881 one-minute samples | `5cfeb7cb9a3bb9fe27700c1903d56f57e73b4109978c0dd7fc097bb986d6a36d` |
| `m5_and_daily_checks.json` | 577 M5 buckets | `966836ed5a435953c7336687c291e50eb902f3cbab54cf56baa283d68cfcd751` |

The deterministic tester-shaped stream spans two complete Prague days, crosses winter midnight at `23:00Z`, restarts once without a sampling hole, plants an equity trough at `94,999`, and ends the second complete day flat above `110,000`.

Observed reader results:

- 2,881 distinct samples, two sessions, one restart, no continuity gap: `PASS`;
- Prague day `20260101`: anchor `100,000`, floor `95,000`, minimum `94,999`, breach `true`;
- Prague day `20260102`: anchor `100,000`, floor `95,000`, minimum `100,000`, breach `false`;
- next one-row day: `ABSTAIN_PARTIAL_DAY` as required;
- first strict target observation: balance/equity `110,001`, zero positions, zero pending orders: `flat_at_target=PASS`.

This is a code-path fixture, not native broker execution evidence and not the `ftmo_free_trial_gate` run.

Reproduction:

```powershell
python tools/strategy_farm/portfolio/ftmo_trial_telemetry.py `
  --input D:/QM/reports/portfolio/ftmo_trial_telemetry_dryrun_20260905_055307/tester_generated_raw.jsonl `
  --output D:/QM/reports/portfolio/ftmo_trial_telemetry_dryrun_20260905_055307/m5_and_daily_checks.json `
  --maximum-sample-gap-seconds 90
```

## Focused verification

```text
python -m pytest -q tools/strategy_farm/tests/test_ftmo_trial_telemetry.py
.....                                                                    [100%]
5 passed in 0.77s

python -m py_compile tools/strategy_farm/portfolio/ftmo_trial_telemetry.py
PASS
```

The synthetic suite covers an exact duplicate across a restart, a conflicting same-identity race, a planted intrainterval minimum, a deliberate sampling hole, flat-at-target, winter/summer Prague midnight, and static absence of trade APIs from the MQL collector.

## Trial-terminal installation checklist

These are preparation instructions. They do not authorize account creation or running the trial.

1. OWNER creates/selects the dedicated FTMO demo or Free-Trial terminal and records its login, server, terminal data path, trial ID, and authorization. Do not use `C:/QM/mt5/T_Live`.
2. Copy `QM_FTMO_TrialTelemetry.mq5` to that terminal's `MQL5/Experts/QM/` and copy the governed `QM_FTMOGovernorPolicy.mqh` include dependency to `MQL5/Include/QM/`. Compile through the normal governed compile workflow; do not manually start a production terminal.
3. Attach exactly one collector instance to the trial account with `InpTrialId=<recorded id>`, `InpExpectedLogin=<exact login>`, `InpExpectedServer=<exact server>`, `InpTimerSeconds=1`, and a trial-specific relative output directory. Account/server mismatch or an unset trial ID fails initialization.
4. Before the candidate trial starts, confirm the raw file begins with a reconciled `INIT` sample and that no other collector writes the same path. Archive any prior trial directory; never truncate a for-record stream.
5. During the trial, tail the file read-only and run the Python reader against copied snapshots. A continuity gap, identity conflict, inventory mismatch, or missing Prague anchor invalidates the affected for-record window; do not repair rows manually.
6. At planned restart/race/midnight exercises, record the exact operator timestamps. Verify a new session after restart, no gap above the preregistered ceiling, correct Prague-key change, and position/pending census on both sides.
7. At trial end, stop only through the OWNER/CEO-approved trial procedure, hash and archive the raw JSONL, run the reader, and bind both hashes into the later acceptance/tail-certification evidence. The scoring contract must be ratified separately before any for-record pass verdict.

The collector is now available, but the trial remains blocked on the OWNER account/MNT-004 decision and the separate exact-profile set, symbol, and acceptance-contract gaps documented in readiness pack 2.
