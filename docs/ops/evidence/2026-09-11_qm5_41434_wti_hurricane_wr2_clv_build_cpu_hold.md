# QM5_41434 WTI Hurricane WR2/CLV Build And Q02 CPU Hold

Date: 2026-09-11

## Outcome

`QM5_41434_wti-hurr-wr2-clv-cont` is a new branch-only WTI D1 structural hurricane-season
sleeve. It buys only when the immediately completed week has a strictly wider full range than the
preceding completed week and closes strictly in its own upper quartile, then exits at the next
normalized week. It is not admitted to the portfolio and makes no decorrelation claim.

## G0 And Q01 Evidence

- source/G0 commit: `c22281a93e`;
- deterministic identity/magic allocation: `3f367e8094`;
- source implementation: `ca33c146a2`;
- canonical dedup: no exact match; one fuzzy neighbor manually resolved;
- card schema lint: PASS, no ML hits or missing sections;
- PACER input-pin audit: exit 0, zero `EA_FRAMEWORK_INPUT_PINNED` findings;
- reference oracle: 12/12 PASS;
- compile work item: `22fb111a-7943-4d87-bebd-0d852497794f`;
- compile: `COMPILE_OK`, 0 errors, 0 compiler warnings;
- strict build check: PASS at `D:/QM/reports/framework/21/build_check_20260911_052845.json`;
- EX5 SHA-256: `4add7e38374ead29926f452e7b7a37f216aa53af144e956719eb67530665ddb5`.

The compile generator blanked `strategy_symbol` because its card discovery was undecidable. The
canonical fixed-risk set was repaired to `XTIUSD.DWX`; Q02 intake dry-run then returned
`ELIGIBLE`, `would_enqueue=true`, D1, `RISK_FIXED=1000`, `RISK_PERCENT=0`, setfile SHA-256
`11e5c47066a73f7acf19044e459bfbb9ba9912556f58670802769d132c7cc9b8`.

## Paced Q02 Decision

Five one-second whole-host CPU samples were `100.0, 100.0, 100.0, 100.0, 100.0` percent. The
maximum exceeded the exclusive 97% ceiling. Q02 enqueue was refused and no backtest, dispatch
tick, terminal control, or retry was run. The eligible intake remains unapplied.

No `T_Live`, AutoTrading, deploy/live manifest, portfolio gate, portfolio admission, or
correlation waiver was touched.
