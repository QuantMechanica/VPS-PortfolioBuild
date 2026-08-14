# QM5_21516 WTI Decoupled Trend — G0/Build/Q01 Evidence

Date: 2026-08-14
Branch: `agents/board-advisor`
EA: `QM5_21516_wti-decoup-trend`
Strategy ID: `MOP-EIA-WTI-DECOUP-2026_S01`

## Outcome

PASS through Q01. The build implements a monthly outright-WTI twelve-month
trend admitted only when the latest 63 synchronized completed-D1 WTI/XNG
simple returns have absolute sample Pearson correlation at or below `0.30`.
`XNGUSD.DWX` is selected, warmed, and read only; only `XTIUSD.DWX` owns slot 0
and magic `215160000`.

This record does not contain a Q02 result or portfolio-diversification claim.
No manual backtest, live/demo/shadow run, AutoTrading action, `T_Live` access,
deploy manifest, portfolio-gate edit, or terminal process control occurred.

## Source And G0

- authorization: `decisions/2026-08-14_qm5_21516_wti_decoup_trend_g0.md`;
- composite source packet:
  `strategy-seeds/sources/MOP-EIA-WTI-DECOUP-2026/source.md`;
- governed parent hashes:
  `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`
  (Moskowitz/Ooi/Pedersen) and
  `4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604`
  (Villar/Joutz; Ramberg/Parsons);
- pre-allocation canonical dedup: `CLEAN`, scanning 4,388 registry rows and
  484 cards; and
- approved-card schema lint: PASS; G0 readiness lint: PASS.

## Allocation And Build Contract

- deterministic EA registry row:
  `21516,wti-decoup-trend,MOP-EIA-WTI-DECOUP-2026_S01,...`;
- magic registry row:
  `21516,wti-decoup-trend,0,XTIUSD.DWX,215160000,...`;
- XNG registry allocation: none (read-only state symbol);
- generated resolver contains magic `215160000` exactly once;
- build prerequisite guard: all of EA row, magic row, and EA directory PASS;
- canonical set generator produced exactly one backtest set for
  `XTIUSD.DWX` D1 with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Validation

| Check | Result | Durable evidence |
|---|---|---|
| strict MetaEditor compile from committed source/resolver | PASS, 0 errors, 0 warnings | `D:/QM/reports/compile/20260814_035623/QM5_21516_wti-decoup-trend.compile.log`; `D:/QM/reports/compile/20260814_035623/summary.csv` |
| target static build check | PASS, 0 failures, 0 warnings | `D:/QM/reports/framework/21/build_check_20260814_035037.json` |
| independent reference suite | PASS, 6 tests | `framework/EAs/QM5_21516_wti-decoup-trend/docs/test_decoupled_trend_reference.py` |
| SPEC validation | PASS, 1/1 | `framework/scripts/validate_spec_doc.py` |
| P1 artifact validation | PASS | `D:/QM/reports/pipeline/QM5_21516/P1/P1_QM5_21516_result.json` |

The independent suite checks perfect positive/negative Pearson vectors,
explicit sample arithmetic, symmetric inclusive threshold boundaries, exact
twelve-month telescoping and direction, exact support and zero-variance
failure, and the read-only state/carrier separation.

## Artifact Hashes

| Artifact | SHA-256 |
|---|---|
| `.mq5` | `B5086D00663D7460C7B103D057D6957E4925D301FEC5B29A4F1423FC1283858B` |
| `.ex5` | `5BF510D937332A4EAA942A9BCD55532BA1DC540D9CA2D006CAB1A59425E80146` |
| backtest `.set` | `B7E1C4480B90D1D2E7D6D1771ED774C6B9951EF05623D856EBC2F053337B963A` |
| approved card | `24A8E594E7529D294A2EC59F2C99A43EC5F5A230201A891B6ECA59E9B87DD88A` |
| composite source packet | `E2ACC15C814EC007D2846F8F7D3D912E93276759DCC34B41FB492C6433BC70D6` |

## Handoff Boundary

Q01 is complete. Before any Q02 queue mutation, read the canonical research
terminal CPU ceiling and slot state. If capacity is binding, stop without
enqueue or terminal action. If capacity is available, perform one idempotent
paced Q02 enqueue and record its work-item identifier separately.
