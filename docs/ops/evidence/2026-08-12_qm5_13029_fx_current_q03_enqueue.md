# QM5_13029 GBPCAD/GBPNZD current-binary Q03 enqueue

Date: 2026-08-12 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: current 90-bar binary Q02 PASS; exactly one append-only Q03 row
pending at immediate readback

## Selection and duplicate boundary

The frozen 66-pair FX scan is fully mechanized. A relationship-level read of
the canonical Strategy Farm found a pair-specific logical Q02 identity for
every ranked relationship. The only open rows from that frontier were the
already-enqueued `QM5_1156` USDCHF/AUDUSD and `QM5_1257` GBPUSD/USDJPY
umbrella bindings. Creating another Card, EA, manifest, or Q02 row would have
duplicated governed work.

The requested anchors are not Q02-blocked:

- `QM5_12532` has Q02 PASS and Q04 PASS followed by Q05 failure evidence.
- `QM5_12533` has Q02 PASS followed by Q04 failure evidence.
- Neither has a current Q02 ONINIT or NO_HISTORY blocker.

The mission fallback therefore advanced the existing, approved, low-frequency
`QM5_13029_gbpcad-gbpnzd-coint` basket. Its current 90-bar build uses the
source-aligned variant already mechanized and enqueued earlier on this branch;
this action did not alter its trading mechanics, risk, registry identity, or
basket manifest.

## Current Q02 evidence

Work item `614cc154-31e1-4919-9a1e-de7bc5e0c5f3` completed Q02 with `PASS`.
The bound summary is:

`D:/QM/reports/work_items/614cc154-31e1-4919-9a1e-de7bc5e0c5f3/QM5_13029/20260812_065459/summary.json`

| Field | Value |
|---|---|
| Logical symbol | `QM5_13029_GBPCAD_GBPNZD_COINTEGRATION_D1` |
| Host / timeframe | `GBPCAD.DWX` / D1 |
| Window | 2018-07-02 through 2022-12-31 |
| Result | PASS |
| Profit factor | 1.10 |
| Trades | 128 |
| Net profit | 1604.00 |
| Drawdown | 3998.10 / 3.82% |
| ONINIT / reason class | false / `OK` |
| EX5 SHA-256 | `957b7065a6fc75d3e81feeab5e4a691872763a8b11203f067676da3758438525` |
| MQ5 SHA-256 | `6d51cdb12a515d26c1ca2fddd3a75eb9927e39dcfd4ceac7422758e4f7ff77bf` |
| Setfile SHA-256 | `0f9a304236e2352de8eca4c4048d7ad07be544889174dbbfab390b9b9c65e693` |

The Q02 setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The four-symbol manifest declares the two traded legs
plus USD-account conversion histories; only GBPCAD and GBPNZD are traded.

## Append-only Q03 action

At `2026-08-12T11:38:33+02:00`, the path-anchored capacity sample found four
factory terminals (`T3`, `T6`, `T7`, and `T8`), below the binding ceiling of
seven. The separately visible live and external terminals were excluded and
not controlled.

The canonical exact-identity enqueue created one row:

| Field | Value |
|---|---|
| Q03 work item | `493a64ad-c9ed-46f4-9d05-1444ef50e645` |
| Status at immediate readback | pending, attempt 0, unclaimed, no verdict |
| Predecessor | current Q02 PASS `614cc154-31e1-4919-9a1e-de7bc5e0c5f3` |
| Append-only source | superseded Q03 PASS `4298cfb6-3ab8-42f8-a455-8d8ba146e6ee` |
| Current binary binding | `957b7065a6fc75d3e81feeab5e4a691872763a8b11203f067676da3758438525` |
| Risk binding | fixed 1000 / percent 0 |

The July Q03 PASS and Q04 FAIL belong to the earlier 60-bar identity and were
preserved. They were not rewritten, reclassified, or used as current-binary
evidence. No current Q04 row was created; Q03 must finish before any later
decision.

## Repository validation

- Canonical and EA-local Card schema/ML lint: PASS; both copies have SHA-256
  `D71A4BDBAC66926BD3CB59136B6AD1EAE36A719980E7EE00F48738A122F29F2F`.
- Target SPEC validation: PASS.
- Target strict static build check with the already-Q02-bound binary: PASS,
  zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260812_094048.json`.
- Manifest JSON parse and exact current-binary Q03 de-dup query: PASS; one
  matching row exists.

## Safety boundary

- No dispatch tick, manual backtest, smoke test, tester launch, terminal
  reservation, or process control was performed.
- No `T_Live` path, AutoTrading setting, deploy manifest, live setfile, or
  live-trading state was touched.
- No portfolio admission, portfolio KPI, or Q08-contribution path was touched.
- No new Card, EA ID, magic row, EA source, EX5, setfile, or basket manifest
  was created.
- Q02 PASS and Q03 enqueue are not certification or portfolio admission.
