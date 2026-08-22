# QM5_20208 NZDUSD/EURAUD Q06 lineage reconciliation

Date: 2026-08-22 UTC (`2026-08-22T21:26:40Z`)

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; existing rank-27 FX basket has one
governed Q06 successor pending and its stale build-local Card lineage is now
reconciled

## Outcome

No new Strategy Card or EA was created. The durable sign-aware reconciliation
in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships from the frozen scan, so another
scan-derived identity would duplicate governed work.

The preferred anchors do not need Q02 repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.

The non-duplicate fallback remains the structural D1 `NZDUSD.DWX` /
`EURAUD.DWX` basket `QM5_20208_nzdusd-euraud`. Its canonical lineage is now:

- Q02 `1935fc01-6eaa-4db1-8397-660d22ebdfbb`: PASS.
- Q04 `3703d3fd-6e3a-4fc2-bc4a-20b2984479b2`: PASS_LOWFREQ.
- Q05 `1a53b4bd-abbd-4c6e-a13a-5f1a1542bf8d`: PASS.
- Q06 `776e6310-7ad6-41ba-8a08-4d63e045d4e5`: PENDING, unclaimed, attempt 0.

The governed cascade created the unique Q06 row at `2026-08-22T20:54:52Z`
from the terminal Q05 PASS predecessor. Its payload binds the canonical basket
manifest, the `NZDUSD.DWX` host, all four required histories, USD 100,000
tester account, 2017-2022 test window, and the tracked fixed-risk backtest
setfile. A fresh canonical query found exactly one Q06 row, so this mission did
not issue a duplicate enqueue or launch a tester.

## Durable Card repair

The build-local Card still reported `Q02_PENDING`. It now records
`Q06_PENDING`, the four canonical work-item identities, and the terminal Q05
metrics: PF 1.17, 108 trades, 2.57823% drawdown, and history from 2018-07-02
through 2025-12-31. This is a lineage-only correction: no beta, z-score,
entry, exit, risk, symbol, magic, or execution rule changed. The immutable
approved source Card remains untouched.

The bound build remains structural and source-backed. Its EX5 SHA-256 is
`31d4460df6cd3e9ef579d8ed4e3849e62b3423ef0e942f6703122e2245988bc4`,
and the basket-manifest SHA-256 is
`ed2fac5d413a6a4665388f73d22606408e51a7e317136e4ac8ed0a8369aa8796`.
The tracked backtest setfile preserves `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`.

## Capacity and safety

The required five-sample whole-host CPU preflight returned 47.67%, 56.94%,
57.35%, 52.84%, and 51.70%. The average was 53.30% and the maximum was
57.35%, below the 97% hard ceiling. One factory terminal (`T2`) was active and
all ten paced workers were present. The existing Q06 row remains owned by the
normal paced selector; no manual dispatch, reservation, terminal control, or
backtest was performed.

- The pre-existing untracked factory Q05 stress setfile was left untouched and
  unstaged.
- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal setting, AutoTrading state, or live artifact
  changed.
- No canonical approved Card, EA, EX5, setfile, basket manifest, registry, or
  magic row changed.

Machine-readable evidence is
`artifacts/fx_cointegration_nzdusd_euraud_q06_lineage_reconciliation_20260822T212640Z_board_advisor.json`.
