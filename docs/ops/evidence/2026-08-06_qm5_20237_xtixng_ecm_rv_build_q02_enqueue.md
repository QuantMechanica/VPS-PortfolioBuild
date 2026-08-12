# QM5_20237 XTI/XNG ECM Build And Q02 Enqueue

Date: 2026-08-06 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: Q01 PASS; exactly one logical-basket Q02 item enqueued and pending

## Outcome

One new structural, low-frequency energy-relative-value candidate was
researched, approved, allocated, built, strictly validated, and placed in the
paced Q02 queue:

- EA: `QM5_20237_xtixng-ecm-rv`.
- Logical carrier: `QM5_20237_XTI_XNG_ECM_D1`, hosted on `XTIUSD.DWX` D1 and
  trading registered XTI and XNG legs.
- Mechanic: fit `log(XNG) = alpha + beta*log(XTI) + gamma*time + residual`
  over exactly 252 synchronized completed D1 observations. Fade only a fresh
  residual crossing outside +/-2 and close at `abs(z)<=0.5`, model failure,
  package failure, or 60 calendar days.
- Regression guards: determinant above `1e-10*Sxx*Suu`, beta in
  `[0.10,2.00]`, `abs(gamma)<=0.01`, finite sigma with 249 degrees of freedom,
  timestamp identity, and a fresh completed endpoint.
- Risk: one `RISK_FIXED=1000` package, `RISK_PERCENT=0`, with frozen relative
  stop-risk weights `abs(beta)` for XTI and `1` for XNG. Both legs receive
  independent `3.5*ATR(20,D1)` hard stops.
- Lifecycle: opposite-side paired orders, second-leg rollback, orphan and
  same-side repair, no repeat while the residual remains beyond a boundary,
  and Friday close disabled for the multiweek convergence thesis.

The opposite directions and beta-weighted risk shares are a construction,
not proof of market, dollar, factor, volatility, or portfolio neutrality. Q02
owns density and economics; a later unchanged portfolio gate alone may test
realized book correlation.

## Source And Non-Duplicate Boundary

The governed packet is
`strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`. It records a
complete read of the 43-page U.S. EIA Villar/Joutz report, a complete read of
Ramberg/Parsons (2012, *The Energy Journal*, DOI
`10.5547/01956574.33.2.2`), and explicit adverse modern EIA context. The
sources motivate a weak, shifting oil/gas long-run relation and gas-side
adjustment; no coefficient, half-life, performance, cost, drawdown, or
correlation result transfers to the CFDs.

The pre-allocation deterministic check scanned 4,294 registry rows and 410
pre-existing cards and returned CLEAN for exact and fuzzy identity. Manual
mechanic review separated this rolling trend-augmented XNG-on-XTI residual
from fixed oil/gas ratios, return spreads, breakouts, shock fades, calendar
effects, trend ranks, volatility ranks, the existing simple XAU/XAG rolling
OLS family, and the incumbent standalone XNG RSI pullback.

## Allocation And Commit Chain

- Source packet and durable G0 decision: `b2cdf675a`.
- EA-ID row, two magic rows, and regenerated resolver: `08df05d9f`.
- Canonical and approved cards: `fa6559fde`.
- Compiled binary and fixed-risk logical-basket setfile: `48dce5629`.
- EA source, SPEC, basket manifest, synchronized card copy, and Q01 state:
  `3686012ca`.

The magic allocation is `202370000` for XTI slot 0 and `202370001` for XNG
slot 1. Resolver regeneration retained 15,518 rows and dropped zero.

## Q01 Evidence

- Strategy-card schema lint: PASS, no missing sections and no forbidden-model
  hits.
- Strict MetaEditor compile: PASS, zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260806_025118/QM5_20237_xtixng-ecm-rv.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260806_025118/summary.csv`.
- Full V5 build check: PASS, zero failures and zero warnings:
  `D:/QM/reports/framework/21/build_check_20260806_025118.json`.
- EX5 size: 377,476 bytes.

Artifact SHA-256 values after the Q02 card-state update:

| Artifact | SHA-256 |
|---|---|
| Source packet | `4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604` |
| G0 decision | `1CD61621AC690A45A027120089BABB6F40F2E214115E09D4E9BCBC05FF61201A` |
| Canonical/approved/build card | `62C09C83A578343143A2F559CFB39438BEC5E9C0A094F6143E92EAA526358488` |
| MQ5 | `5C2F786F9C293D668697CF125F988ACAC85DB5589148163D55137F4A904CC310` |
| EX5 | `2C87D0F96364057462C0BDC44AD36C45B0379EAADF91BC1949EC888C528D5992` |
| SPEC | `56515B91E285EE84B745E38ACFF4FBA912CDBB94692E010E5F76550A52E61870` |
| Basket manifest | `8D64B45E1B1766BE3E687AFBC0B53194CE1920E3496663B60342C7D031C49C92` |
| Backtest set | `0CEB78F0C6817E681EA8ED694A8ABA26366980E00636AB5426670DA1A9E3F2FC` |

## Q02 Enqueue Evidence

The exact scoped no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20237 --symbols QM5_20237_XTI_XNG_ECM_D1 --max-part2-per-run 0

It selected exactly one `never_tested` priority-track item, no stranded item,
and no recovery item. The first apply attempt was safely skipped because the
canonical `FACTORY_MUTATION.lock` was held by another factory operation. The
lock was neither removed nor modified. It cleared normally, after which the
terminal ceiling was rechecked before one retry.

Read-only `farmctl.py mt5-slots` scans at `2026-08-06T02:54:58Z` and
`2026-08-06T02:55:48Z` both found six active factory terminals: T1, T2, T5,
T8, T9, and T10. Six was below the binding ceiling of seven. The apply run
then inserted exactly one priority-track item. The generated sweep record is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`; it records 1,501
pending rows at start against the separate queue ceiling of 7,000.

Post-apply verification found exactly one row for `QM5_20237`:

| Field | Value |
|---|---|
| work item | `2e79b80d-2942-491a-a440-4ab92a7c642f` |
| phase | `Q02` |
| symbol | `QM5_20237_XTI_XNG_ECM_D1` |
| status | `pending` |
| attempt count | `0` |
| claimed by | none |
| created UTC | `2026-08-06T02:55:57Z` |

No dispatch tick was called. Normal paced workers own the first CPU-bearing
run and the card's hard floor of at least five completed packages per year.

## Safety Boundary

- No manual backtest, smoke run, dispatch tick, terminal reservation, tester
  launch, process mutation, or lock removal was performed.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
- Existing unrelated working-tree changes were preserved and excluded from
  task commits.
