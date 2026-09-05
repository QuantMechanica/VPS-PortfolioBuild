# M09 exact FTMO binaries: scenario preflight — REVIEW / UNTESTABLE

Task `3d2c9e2f-59a0-4bf7-8933-a3f2b2738721`. Eight requested scenarios were
evaluated by the headless preflight harness. **0 native PASS, 0 native FAIL,
8 UNTESTABLE.** Joint account-risk control on the exact target binaries remains
unproven. The output records an execution blocker, not completion of that proof.

## Bound target and observed lane state

[target_bindings.json](2026-09-05_m09_joint_risk_telemetry/target_bindings.json:1)
binds the existing immutable eight-sleeve trial manifest, every target binary and
each trial set. All **8 binary hashes and 8 set hashes match** their manifest.
Targets are 10706/GBPUSD, 11421/EURUSD, 11422/USDCAD, 11910/NZDUSD,
13054/USOIL.cash, 1537/XAGUSD, 20048/USOIL.cash and 21505/XAGUSD.

[lane_inspection.json](2026-09-05_m09_joint_risk_telemetry/lane_inspection.json:1)
captures both isolated FTMO_STREAM lanes through the existing pure inspection
function (`ftmo_lane_runner.py:396`). Both configured profiles identify FTMO-Demo,
both have Experts explicitly disabled, and both report **HOLD /
NATIVE_HISTORY_WINDOWS_UNPROVEN**. Neither lane contains a named target candidate
copy, the compiled trial collector, or a `trial_telemetry_raw.jsonl` stream under
its MQL5 files root. No bound shared-account scenario execution receipt exists
in this task's inputs.

The existing runner is a single-EA backtest runner (`ftmo_lane_runner.py:710`),
requiring **RISK_FIXED > 0 and RISK_PERCENT = 0** (`:555`). Its actual validator
rejects all eight percentage-risk trial sets. No guard was weakened, no set
was converted to make a different experiment look equivalent, and no terminal
was started. A separately bound shared-account trial harness is needed to prove
simultaneous candidate execution and account-wide reservations.

The provision CLI refused the canonical evidence destination because admission
receipts are restricted to `D:/QM/reports/state`. No admission receipt was written
there. The pure inspection result is retained inside a distinct
`qm.m09-lane-observation/v1` evidence envelope marked `admission_receipt=false`;
it is not offered to the execution runner as a valid admission receipt.

## Scenario matrix

The executable preflight matrix and concrete acceptance conditions are in
[scenario_matrix.json](2026-09-05_m09_joint_risk_telemetry/scenario_matrix.json:1).

| Scenario | Native result | Evidence still required |
|---|---|---|
| Reservation activation | UNTESTABLE | Exact binary/input activation and reservation before submit, release after reject/fill |
| Simultaneous entries | UNTESTABLE | At least two target entry requests on one account; atomic budget admission/refusal |
| Pending orders | UNTESTABLE | Pending stop risk, reservation, cancellation, fill and orphan recovery |
| Restart | UNTESTABLE | Isolated restart with inventory and reservation reconciliation before new entry |
| Disconnect/reconnect | UNTESTABLE | Isolated connection interruption, blocked unsafe entries, measured telemetry gap and recovery |
| Foreign positions | UNTESTABLE | Non-roster position explicitly included in account risk and attributed separately |
| Measurement resolution | UNTESTABLE | Exact compiled collector, target-account identity, Prague anchors and observed cadence |
| Intraday trough | UNTESTABLE | Native trough between M5 endpoints and defensible bounds on unsampled loss |

These are runtime evidence gaps shared across the eight exact candidates. A
Python fixture or separate single-EA backtests cannot prove shared-account
reservation atomicity. No live account, T_Live process or active factory backtest
was used to stage a disconnect, restart, entry or foreign position.

## Reader replay and measurement limits

The earlier 2,881-row fixture was copied without alteration into
`synthetic_reader_fixture.jsonl` and evaluated with the current
`ftmo_trial_telemetry.py` reader. The captured result is explicitly
**SYNTHETIC_READER_FIXTURE_ONLY**, with `exact_candidate_binaries_executed=false`.
It reproduces 577 M5 buckets, one restart, the planted **94,999** equity trough,
a detected daily breach, and the flat strictly-above-target observation.
Its 90-second gap limit belongs to the one-minute synthetic fixture. It is not
adopted as a native experiment's resolution or risk threshold.

The reader takes the minimum of observed tick/timer samples. This is an upper
bound on true minimum equity; an unobserved interval can contain a lower trough.
Timer observations during disconnection may repeat stale account state, so a
regular timer alone cannot certify server-state coverage. The native test needs
explicit connection/reconciliation events in addition to timestamps, and a
bound collector/target-account identity. Reservation acquisition/commit/release
events are also necessary: the current raw sample inventory by itself does not
show pending reservations that have not yet become broker orders.

## Verification and next execution boundary

`run_matrix.py` hashes the eight immutable targets, inspects both lanes, runs
the eight preflight classifications and replays the labeled fixture. It only
creates new evidence files and refuses existing outputs. Current production
reader/lane tests passed: **26 passed**, including restart/duplicate identity,
gap detection, Prague day boundaries, risk-mode refusal and lane admission
guards. Code and artifact hashes plus the test receipt are in `verification.json`.

The next executable native run requires proven history/symbol contracts, a
bound exact-profile isolated account scenario adapter, compiled collector and
candidate installation, reservation-event instrumentation and authorized trial
operation. This scheduled cycle cannot enable AutoTrading or operate the live
account. These dependencies are reported for the existing task's review; no new
untracked work was selected, no gate verdict was issued, and no purchase or
deployment occurred.
