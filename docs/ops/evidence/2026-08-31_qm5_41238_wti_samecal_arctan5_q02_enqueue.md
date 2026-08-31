# QM5_41238 WTI same-calendar arctangent sleeve — Q02 enqueue

Date: 2026-08-31

Branch: `agents/board-advisor`

Outcome: `NEW_STRUCTURAL_WTI_SLEEVE_Q01_PASS_Q02_ENQUEUED`

## Delivered edge

`QM5_41238_wti-samecal-arctan5` is a new low-frequency direct-WTI structural
calendar sleeve. On the first genuine normalized `XTIUSD.DWX` broker-month
transition into `(Y,M)`, it reconstructs the completed log return for the same
named calendar month in exact years `Y-5..Y-1`; all five observations are
mandatory.

The estimator starts at the odd median, freezes `scale=1.4826*MAD`, and executes
exactly 32 arctangent derivative-weight updates:

```text
u[i]      = (r[i] - mu[j]) / scale
weight[i] = 1 / (1 + u[i]^4)
mu[j+1]   = sum(weight[i] * r[i]) / sum(weight[i])
```

The EA buys only above `+1e-12`, sells only below `-1e-12`, and consumes the
month flat at equality or on invalid state. It persists the consumed attempt
before history and entry gates. Positions carry a frozen `3.5*ATR(20,D1)` hard
stop, exit at the next normalized month, and have a 40-day survivor repair.

This is direct WTI exposure outside the currently certified XAU/SP500/NDX/XNG
carrier set. That is a structural diversification objective, not a realized
decorrelation claim; unchanged Q09 remains the only authority for portfolio
overlap and value.

## Non-duplicate and source evidence

The bounded source packet combines complete peer-reviewed same-calendar
commodity and WTI own-return lineages with the official SciPy arctangent loss
definition. The five-return conjunction, continuous-CFD translation, scale,
update count, sign epsilon, stop, spread, and lifecycle are disclosed QM choices.

The corrected-root dedup receipt scanned the deterministic identity/card/Wiki
stores and found no exact identity. Its expected fuzzy results are neighboring
same-calendar robust-location estimators, not duplicates.

The locked fixture `[-0.095,-0.045,-0.005,+0.050,+0.060]` produces an
arctangent location of approximately `+0.006280955600` (BUY), while the matched
Cauchy sibling produces approximately `-0.002436516741` (SELL). Raw mean is
`-0.007` and raw median is `-0.005`. The quartic-tail weight therefore changes
actual participation, not merely naming or parameter labels.

Governance records:

- source approval: `decisions/2026-08-31_wti_same_calendar_arctan5_source_approval.md`;
- bounded source packet: `strategy-seeds/sources/KELOHARJU-SCIPY-WTI-SAMECAL-ARCTAN5-2026/source.md`;
- approved card: `strategy-seeds/cards/approved/QM5_41238_wti-samecal-arctan5_card.md`;
- G0 decision: `decisions/2026-08-31_qm5_41238_wti_same_calendar_arctan5_g0.md`;
- canonical dedup: `artifacts/qm5_wti_samecal_arctan5_preallocation_dedup_20260831.json`.

## Build and Q01 result

The governed identity is `QM5_41238`, slot 0, magic `412380000`. The EA, SPEC,
one D1 `RISK_FIXED` setfile, local byte-identical card, independent fixtures,
and compiled binary are committed on the branch.

Q01 utility work item `96597175-b978-4663-86e0-ab4b448bee4d` completed on T9:

- verdict: `COMPILE_OK`;
- strict compile: PASS, 0 errors, 0 warnings;
- strict build-check: PASS;
- failure classes: none;
- setfiles: exactly one;
- MQ5 SHA-256: `391996435e5b4f99dc0be92a95e153fc185a3776eacd12c5cdc72a82217447ef`;
- EX5 SHA-256: `102916d14a92333b5ab50b77508c4f0bbf663d3ce85cb236dd5c97e02af30eeb`;
- evidence: `D:/QM/reports/work_items/96597175-b978-4663-86e0-ab4b448bee4d/QM5_41238/COMPILE_EA/compile_evidence.json`.

Additional validation:

- independent reference suite: 11 passed;
- governed allocator/precheck suite: 17 passed;
- card schema lint: PASS;
- SPEC validation: PASS;
- strategy-entry validation: PASS;
- raw-source quarantine: PASS;
- scoped static build guardrails: PASS, zero findings.

The sole backtest preset locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; its build hash is sealed.

## Paced Q02 enqueue

The final whole-host five-sample CPU window immediately before the queue
mutation was `68.5078%, 68.8314%, 68.3628%, 68.2654%, 73.8051%` (average
`69.5545%`, maximum `73.8051%`). Both were below the 97% hard ceiling.

Build task `1dcf4bb6-7684-4531-b77b-e36c91b6d063` was recorded as strict Q01
PASS with the build-only smoke boundary preserved. No manual backtest was
launched. The canonical record-build route created exactly one Q02 row:

- work item: `313a6f99-9730-4563-88d7-55866782c4f9`;
- phase/status at readback: `Q02 / pending`;
- symbol/timeframe: `XTIUSD.DWX / D1`;
- attempt count: 0;
- claimed by: none;
- duplicate/skipped rows: none;
- custom-history archive admission: ACTIVE, 108 selected rows;
- priority track: true.

The row is enqueued for the resident paced fleet. This session did not dispatch
or execute it.

## Branch commits

- `184a4ebc7` — source approval;
- `99c197e13` — bounded source packet;
- `91c2823ac` — identity reservation;
- `dd6650493` — approved card and G0 record;
- `86986acbf` — magic allocation and resolver binding;
- `2b94a298c` — EA, SPEC, and fixed-risk setfile;
- `f0925f3b6` — independent reference tests;
- `f3ca37be6` — exact governed compile release;
- `497ca6700` — compiled binary and sealed setfile;
- `e65bd7617` — governed build task and build result.

## Safety boundary

No manual backtest, AutoTrading change, `T_Live` control or manifest, deploy
manifest, portfolio gate, portfolio admission, correlation waiver, or
certification state was touched. No live-use, performance, or realized
decorrelation claim is made.

Machine-readable receipt:
`artifacts/qm5_41238_wti_samecal_arctan5_q02_enqueue_20260831.json`.
