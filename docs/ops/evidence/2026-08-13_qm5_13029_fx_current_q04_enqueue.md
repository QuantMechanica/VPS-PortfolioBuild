# QM5_13029 GBPCAD/GBPNZD current-binary Q04 enqueue

Date: 2026-08-13 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: current 90-bar binary Q02/Q03 PASS; exactly one append-only Q04 row
pending at verification

## Outcome

The frozen sign-aware 66-pair scan is fully mechanized, so creating another
Card or EA would be duplicate work. The existing-card fallback advanced
`QM5_13029_gbpcad-gbpnzd-coint`, a low-frequency D1 market-neutral
`GBPCAD.DWX` / `GBPNZD.DWX` basket, from current-binary Q03 PASS into Q04.

The canonical enqueue created exactly one work item:

| Field | Value |
|---|---|
| Q04 work item | `1c2f3328-71e3-4c47-a8f5-5a583193b4cb` |
| Logical symbol | `QM5_13029_GBPCAD_GBPNZD_COINTEGRATION_D1` |
| State at verification | PENDING, unclaimed, attempt 0, no verdict |
| Current claim rank | 5 |
| Promoted from | Q03 PASS `493a64ad-c9ed-46f4-9d05-1444ef50e645` |
| Preserved prior Q04 | terminal 60-bar FAIL `629d9f34-d7a4-42e6-82f0-c7b4d26289b7` |
| Event | `347676`, `cascade_backtest_enqueued` |

The action created one row, requeued zero, skipped zero, and left the prior
Q04 evidence immutable.

## Duplicate and anchor guard

The relationship audit at commit `a80493291` accounts for all 66 frozen scan
relationships. The two requested anchors do not have a current Q02 setup
blocker:

- `QM5_12532` has logical Q02 PASS and Q04 PASS, followed by Q05 FAIL.
- `QM5_12533` has logical Q02 PASS, followed by Q04 FAIL.
- Neither anchor has an open Q02 `ONINIT` or `NO_HISTORY` failure.

`QM5_13029` was selected because its already-approved 90-bar identity had
completed the exact current-binary Q02 and Q03 gates but had no current Q04
row. The July Q04 FAIL belongs to the preserved 60-bar identity, so the new
row is an append-only continuation rather than a rewrite or duplicate retry.

## Source and structural contract

The approved Card cites Ernest P. Chan, *Quantitative Trading* (Wiley, 2009),
plus the OWNER-directed extended Darwinex FX screen. That screen recorded an
OOS-heavy `GBPCAD` / `GBPNZD` relationship with OOS net Sharpe 1.66, DEV net
Sharpe -0.11, and an estimated 84.8-day half-life. The 90-bar state window was
already predeclared and approved before this action.

The EA uses closed D1 prices, fixed beta `0.3460`, fixed residual z-score
thresholds, ATR hard stops, broken-package cleanup, and opposite-direction
legs. It has no online refit, ML, banned indicator, grid, martingale,
pyramiding, averaging down, or new rescue filter.

The logical setfile remains backtest-only fixed risk:

- `RISK_FIXED=1000`;
- `RISK_PERCENT=0`; and
- `PORTFOLIO_WEIGHT=1`.

The four-symbol manifest declares `GBPCAD.DWX` and `GBPNZD.DWX` as traded legs
and `USDCAD.DWX` / `NZDUSD.DWX` as USD-account conversion-history
dependencies.

## Current evidence and bindings

Current Q02 work item `614cc154-31e1-4919-9a1e-de7bc5e0c5f3` and current Q03
work item `493a64ad-c9ed-46f4-9d05-1444ef50e645` both returned PASS on the
same binary and setfile. The Q03 summary contains two deterministic completed
runs, each with 128 trades, PF `1.10`, net profit `1604.00`, drawdown
`3998.10` / `3.82%`, and reason class `OK`. No `ONINIT`, history, real-tick,
or incomplete-run defect was present.

| Artifact | SHA-256 |
|---|---|
| Approved Card and EA-local copy | `966f6a3e52c577fb44892cb00c41ce250ec31a1d583de86db9abee2bb932ec8b` |
| MQ5 | `6d51cdb12a515d26c1ca2fddd3a75eb9927e39dcfd4ceac7422758e4f7ff77bf` |
| EX5 | `957b7065a6fc75d3e81feeab5e4a691872763a8b11203f067676da3758438525` |
| Basket manifest | `3295e479a33e2e6ab9ffa71e26f5bdabd88af0d26cdf2897157d584c34dd8069` |
| Logical fixed-risk setfile | `0f9a304236e2352de8eca4c4048d7ad07be544889174dbbfab390b9b9c65e693` |
| Current Q03 summary | `1a8c14045993572cfce39bf37d6c3f26822f0f2c94e8743d375a32303a445bf7` |
| Preserved 60-bar Q04 aggregate | `bc182ed679d05efc5f3e91b8f6c7fabafd021425896e703a41bda6409ba490cc` |

The new Q04 payload binds the exact MQ5, EX5, setfile, expert, D1 period,
`GBPCAD.DWX` host, logical basket, fixed-risk values, Q03 predecessor, and
preserved Q04 work item.

## Validation, capacity, and safety

- Strategy Card schema/ML lint: PASS, no missing sections or ML hits.
- SPEC validation: PASS.
- Symbol-scope validation: `BASKET_OK`, zero violations.
- Immediate pre-enqueue capacity: zero running factory terminals against the
  paced maximum of one; `FACTORY_OFF.flag` absent.
- Post-enqueue process scan: zero factory terminals, workers, reservations,
  duplicates, or orphans. The unrelated FTMO terminal was excluded and not
  controlled.
- No dispatch tick, manual tester, terminal reservation, or backtest was
  started by this action.
- No portfolio admission, portfolio KPI, Q08 contribution, `T_Live` manifest,
  live setfile, AutoTrading, or live terminal surface was touched.

Machine-readable evidence:
`artifacts/qm5_13029_fx_current_q04_enqueue_20260813T021908Z_board_advisor.json`.
