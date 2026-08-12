# QM5_20012 XAU/XAG C-MTAR Q02 Timeout Recovery

Date: 2026-08-02

Branch: `agents/board-advisor`

EA: `QM5_20012_xauxag-cmtar`

Logical basket: `QM5_20012_XAU_XAG_CMTAR_D1`

## Selection and farm coordination

This was the highest-value collision-free infrastructure recovery after the
approved build backlog was screened for structural, low-frequency diversity.
The EA is a D1 XAU/XAG relative-value package based on the fixed C-MTAR
relation in Mighri and Al Saggaf (2018). It has a peer-reviewed source, no ML
or banned indicator, and one combined `RISK_FIXED=1000` package budget.

- Exclusive agent task: `7744cf23-0842-45e6-81b6-8cbfd388aa7b`
- Claim key:
  `manual:codex:agents/board-advisor:QM5_20012:q02-timeout-recovery:20260802T180916Z`
- Pre-claim SQLite backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_20012_q02_timeout_claim_20260802T180916Z.sqlite`
- Claim-time guard: no pending/active work item, active legacy build task, or
  competing EA-scoped agent task existed.

## Prior failure evidence

Both prior Q02 attempts were infrastructure-only. Neither produced an
economic verdict.

| Work item | Terminal | Bound window | Verdict |
|---|---|---|---|
| `34f0fd25-452f-40ec-a739-94cd00b26db2` | T7 | 2018-07-02 through 2024-12-31 | `TIMEOUT; METATESTER_HUNG; INCOMPLETE_RUNS` after 7,200 seconds |
| `9f0b64df-3864-437c-9a3e-c83bb0fa4aaf` | T10 | 2018-07-02 through 2024-12-31 | `TIMEOUT; METATESTER_HUNG; INCOMPLETE_RUNS` after 7,200 seconds |

The second report proved the source, deployed EX5, and setfile remained stable
during the run. There was no `OnInit` failure and no log bomb. The EA's
monthly signal nevertheless performed repeated two-leg position,
composition, and notional-hedge scans on every XAU real tick while a package
was open. The old build also retained the review finding that its current
month scheduling was derived from a raw per-EA calendar key.

## Repair

The source relation, residual orientation, `delta(e) < 0.021` gate, residual
buffer, entry directions, 0.71970 hedge, joint sizing, ATR stops, 40-day stop,
and monthly renewal were not changed.

- Current-period identity now comes from
  `QM_CalendarPeriodKey(PERIOD_MN1, XAUUSD.DWX)`.
- The exact D1 bar-open remains the strict monthly history cutoff.
- Two-leg composition and hedge validation now run after a trade-state change
  or on a completed D1 bar. `OnTradeTransaction` marks state dirty and repair
  occurs on the next host tick, avoiding an in-flight first leg being mistaken
  for an orphan.
- Broker hard stops and `QM_KillSwitchCheck()` remain active on every tick.
- The SPEC records the lifecycle scheduling change.

## Validation

- Focused V5 build check: `PASS`, zero failures and zero warnings.
- Compile: `PASS`, zero errors and zero warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260802_181224.json`
- SPEC validator: `PASS` for this EA.
- The repository-wide registry validator still reports the pre-existing bulk
  legacy registry debt; the active `20012` EA row and both magic rows are
  present and unchanged.
- One smoke invocation was run with automatic terminal dispatch, Model 4,
  D1, `-SmokeMode`, and the logical fixed-risk setfile. It produced two
  deterministic 2024 runs on T10; each completed with 8 leg trades, PF 1.50,
  net profit 513.80, and 0.74% drawdown. Both reports and logger samples were
  non-empty and identical on trading metrics. The two-run invocation completed
  in 809.8 seconds rather than reaching the former 7,200-second wall.
- Smoke summary:
  `D:/QM/reports/smoke/QM5_20012/20260802_181335/summary.json`

Artifact identities used by the smoke and Q02 handoff:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `00540b65323c1ea082c6edcca0f92786523a7f011b07553d91a23d4bfdd57b96` |
| EX5 | `ebb1793b1faaea99b6354b5146b9fad605ef830bff39862a9a55411ae13f8fc7` |
| Logical setfile | `ffaeb08abe752065533b44ef4628811f4e88cc318ec68008ddb07a50b727a06a` |

## Q02 handoff

- Build task: `06aa245f-b650-4088-bb34-1c0718f1f14c` (`done`)
- New append-only work item:
  `10b43597-ea67-4664-8e71-b3e359bac517`
- Initial state: `pending`, unclaimed, attempt 0
- Window: 2018-07-02 through 2024-12-31
- Runner contract: one logical basket work item, XAU host, XAG foreign leg,
  D1, tester deposit USD 100,000, timeout 450 minutes

The worker binds the current MQ5, EX5, setfile, expert, symbol, period, and
date window when it claims the row. Generic trade totals count legs; the
card's minimum completed-package density remains a separate Q02 review
requirement. No standalone-leg fanout, T_Live action, AutoTrading change,
portfolio-gate change, deploy manifest, or live preset was created.
