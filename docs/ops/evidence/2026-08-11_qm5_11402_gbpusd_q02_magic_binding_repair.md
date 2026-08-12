# QM5_11402 GBPUSD Q02 magic-binding repair

Timestamp: `2026-08-11T00:12:22Z`

## Decision

No new cointegration pair was created. The governed 66-pair FX frontier is
already exhausted: the repository covers ranks 1-64 directly, rank 65 through
`QM5_1156`, and rank 66 through `QM5_12803`. The two anchor baskets are not
blocked at Q02:

- `QM5_12532`: Q02 PASS, Q04 PASS, Q05 FAIL.
- `QM5_12533`: Q02 PASS, Q04 FAIL.

Creating another basket Card would therefore duplicate an existing
relationship. The authorized fallback was applied to the existing structural,
low-frequency forex sleeve `QM5_11402_davey-dueling-momentum-d1`, specifically
`GBPUSD.DWX` on D1.

## Failure and repair

Terminal source work item
`9659574a-b214-4eb0-a321-ae127c56c9b4` ended `INFRA_FAIL`. Its preserved tester
log contains:

```text
EA_MAGIC_NOT_REGISTERED: ea_id=11402 slot=1 magic=114020001
tester stopped because OnInit returns non-zero code 1
```

The deterministic registry already contained the active slot-1 mapping
`114020001`, and the committed resolver already contained that magic. The MQ5
source was left unchanged. The stale EX5 was force-recompiled against the
committed resolver:

- MQ5 SHA-256 (unchanged):
  `4cb23b969157605aa1364eb5f029b6570467316367b3aecc87643b1803354b55`
- old EX5 SHA-256:
  `1a2ca96003502f8b3cf86f355037e39e9344338a690c4fa8805ac83f9dd92a00`
- repaired EX5 SHA-256:
  `5a05c726898fd8e5b4f910afdda3853d2f39cf0e4c2fd5a0435ba2066badf70f`
- GBPUSD backtest setfile SHA-256:
  `b8e956a37d0f4aa25cd6eed6dffb02eb8e290aac83f647ce5e9e315addd0db31`

The build is committed on `agents/board-advisor` as `d5d50e7a8`.

## Gates

- strict MetaEditor compile: PASS, 0 errors, 0 warnings;
  `D:/QM/reports/compile/20260811_000736/summary.csv`
- V5 build check: PASS, 0 failures, 0 warnings;
  `D:/QM/reports/framework/21/build_check_20260811_000815.json`
- Card schema lint: PASS, no missing sections and no ML hits.
- EA build guard: PASS for EA registry, magic registry, and EA directory.
- GBPUSD setfile: D1, slot 1, `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- The repository Card normalizes the already OWNER-approved Kevin J. Davey
  source boundary; it adds no symbol-performance claim and changes no trading
  mechanic.

## Q02 handoff and duplicate guard

The fleet had already created pending Q02 work item
`70d42e0f-7e9b-4d81-8a8a-ffcad70a7805` for the same EA/symbol at
`2026-08-10T23:52:58Z`, sourced from the terminal failure above. It remains the
single open `QM5_11402` / `GBPUSD.DWX` Q02 row. No duplicate row was inserted.

That pending payload has no pre-claim execution hashes. The farm dispatcher
resolves the current canonical EX5, MQ5, and setfile hashes immediately before
spawn and records them in the claimed payload. Consequently, this row will bind
the repaired EX5 when dispatched.

The immediate capacity sample at `2026-08-11T00:11:19Z` reported five running
factory MT5 terminals (`T1`, `T2`, `T4`, `T5`, `T8`) against the seven-terminal
backtest ceiling. The separate T_Live and FTMO desktop processes were excluded
from that factory count and were not controlled or modified.

## Safety

- No backtest was launched manually.
- No T_Live file, manifest, or AutoTrading state was touched.
- No portfolio-admission, KPI, or Q08-contribution gate was touched.
- Unrelated dirty worktree files were neither staged nor committed.
