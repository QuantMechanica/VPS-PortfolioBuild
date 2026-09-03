# QM5_41319 WTI ADF Persistence Trend — Source Build And CPU Stop

Date: 2026-09-03  
Branch: `agents/board-advisor`  
Status: source build committed; governed Q01 successor held; Q02 not enqueued

## Outcome

`QM5_41319_wti-madf-persist-tr` is a new direct-WTI, structural,
low-frequency candidate outside the certified XAU/SP500/NDX/XNG book. It uses
sixty completed broker-month WTI log closes, a constant/no-time-trend
lag-one augmented Dickey–Fuller regression, an inclusive `adf_t >= -2.594`
persistence-state gate, and the sign of the newest twelve-month log return.
It is not a KPSS, autocorrelation, ARCH, BDS, entropy, variance-ratio, calendar,
channel, pure momentum, or XNG RSI implementation.

The threshold is deliberately described only as a frozen state boundary. This
build makes no p-value, unit-root, performance, activity, or correlation claim.
Q09 remains the sole portfolio-correlation authority.

## Committed chain

- `d486b131e7` — reputable-source packet, approval, clean corrected-root
  duplicate scan, and three-path arithmetic fixture.
- `6c21f381b7` — OWNER-authorized G0 Strategy Card.
- `214d712410` — deterministic EA identity `QM5_41319`.
- `e87c1e319e` — active `XTIUSD.DWX` slot-zero magic `413190000`.
- `28b8322048` — EA source, SPEC, independent reference suite, and sole
  fixed-risk backtest set.
- `83687f8440` — tested append-only compiler repair support for the narrow
  case where a source-changed failed predecessor was enqueued before its build
  task existed.

The source build pins `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Its independent suite passed 9/9 tests. MQ5 SHA-256 is
`B13F136A3358E3B3EC3B11374993D86D2BE27C388FB6DD729C7B42C89C806F70`;
the setfile SHA-256 is
`7382B8EE53055F7933FAAB1E2FC10CEAAF482FE8227A5482BF44568B85A244D2`.

## Governed compile state

An ad-hoc strict compile was refused before MetaEditor execution with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`, because fleet terminals were active.
No retry through the ad-hoc path occurred.

The first governed row
`07211f28-64ad-4ea4-9527-32d43c08e8c9` failed closed before compilation with
`SOURCE_CHANGED_AFTER_ENQUEUE`: its enqueue hash preceded the final blank-line
normalization. That immutable failure remains at:

`D:/QM/reports/work_items/07211f28-64ad-4ea4-9527-32d43c08e8c9/QM5_41319/COMPILE_EA/compile_evidence.json`.

The governed build task is
`cd3a3f60-895d-49cc-850c-c2c42f09cc9d`. A dry run authenticated the current
source delta and sole open build-task binding. The append-only successor
`74fb5a2d-a4cd-43e3-bc12-e7dbeac67ac1` was created under
`COMPILE_EA_WORKER_ROLLOUT_PENDING`; the failed row was not edited.

## Mandatory CPU stop

The fresh five-sample host admission series immediately before successor
release was:

`93.7515, 96.9881, 99.6102, 100.0000, 99.9121`

Average was `98.0524%` and maximum was `100.0000%`. Both violate the
`97%` ceiling. Work therefore stopped before releasing the successor.
There is no EX5, Q01 PASS, or Q02 row. The backtest set retains
`build_hash: PENDING_COMPILE`.

Required continuation is bounded: after a fresh below-ceiling sample, release
only successor `74fb5a2d-a4cd-43e3-bc12-e7dbeac67ac1`, let the canonical
worker compile and run strict build checks, record/review that exact build
generation, then dry-run and enqueue exactly one XTIUSD.DWX D1 Q02 item if all
gates pass.

## Safety boundary

No manual tester or backtest ran. No terminal was started, stopped, reserved,
or reaped. AutoTrading was not toggled. No `T_Live` file, live manifest,
portfolio gate, or deployment surface was modified.
