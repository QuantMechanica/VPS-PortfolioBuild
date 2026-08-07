# QM5_20260 XAU/XAG Momentum Vote Q01 And Q02 Enqueue

Date: 2026-08-07 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20260_xauxag-mom-vote` is built and Q01 is `PASS`. Q02 is
`ENQUEUED`: work item `247fc177-43a3-4bc2-aa66-9a10ed42c151` was read back as
pending, unclaimed, and attempt 0 for logical basket
`QM5_20260_XAU_XAG_MOMVOTE_D1` immediately after the single apply-mode
enqueue. No dispatch command or manual backtest was run.

## Edge And Non-Duplicate Boundary

At the first processed XAU D1 bar of a genuine new broker month, the EA
reconstructs thirteen consecutive synchronized completed month-end closes for
XAU and XAG. For each of the one-, three-, and twelve-month formation windows,
it compares the two metals' arithmetic average completed monthly returns. A
strict two-of-three vote buys the winning metal and sells the losing metal for
the new month. A tied component, invalid arithmetic, timestamp mismatch,
nonconsecutive history, or stale endpoint consumes the month flat.

The two legs share one fixed cash-risk budget after independent ATR
normalization. Each receives a frozen `3.5*ATR(20,D1)` stop. The package renews
at the next broker month, has a forty-calendar-day stale guard, and is repaired
atomically if either leg or stop is inconsistent.

The deterministic pre-allocation checker scanned 4,317 EA-registry rows and
434 cards, found no exact slug or strategy-ID collision, and returned seven
expected fuzzy neighbors. Manual review resolved them:

- `QM5_20050`, `QM5_20057`, and `QM5_20184` are single-horizon XAU/XAG
  cross-sectional ranks at twelve, one, and three months respectively;
- `QM5_13126` and `QM5_20051` rank XTI against XNG rather than XAU against
  XAG; and
- `QM5_20258` and `QM5_20259` apply the same horizon-vote shape to one
  outright WTI or XNG return series rather than an opposite-leg metal basket.

The exact one/three/twelve arithmetic-average rank comparisons, strict
component validity, two-of-three aggregation, synchronized two-metal history,
opposite legs, shared risk, persisted monthly attempt, and package renewal are
jointly load-bearing. This is a market-neutral relative metal exposure rather
than another outright XAU, SP500, NDX, or XNG carrier. Realized neutrality and
decorrelation are not claimed; Q09 alone may measure them if every preceding
gate passes.

## Source And G0 Record

The tier-A source is Fuertes, Miffre, and Rallis (2010), "Tactical Allocation
in Commodity Futures Markets: Combining Momentum and Term Structure Signals,"
*Journal of Banking & Finance* 34(10), 2530-2548, DOI
`10.1016/j.jbankfin.2010.04.009`. The complete governed review is
`strategy-seeds/sources/FMR-MOMTS-2010/source.md`; the bounded XAU/XAG vote
extraction is `strategy-seeds/sources/FMR-XAUXAG-MOMVOTE-2026/source.md`.

The source supplies average-past-return commodity ranks and explicitly reports
one-, three-, and twelve-month formation horizons with a one-month hold. The
majority aggregation and two-CFD carrier are transparent QM hypotheses, not
author results. No source profitability, density, CFD basis, neutrality, or
portfolio-correlation result transfers.

G0 authorization is
`decisions/2026-08-07_qm5_20260_xauxag_mom_vote_g0.md`. The authorization is
commit `1bb67d031`, source/card approval `02daad673`, deterministic registry
allocation `2b6336466`, and build `70432237d`.

## Deterministic Allocation And Q01 Evidence

- EA ID/slug: `QM5_20260` / `xauxag-mom-vote`.
- Strategy ID: `FMR-MOMTS-2010_XAU_XAG_MAJ1312_S05`.
- Symbols/slots/magics: `XAUUSD.DWX` / 0 / `202600000` and `XAGUSD.DWX` /
  1 / `202600001`.
- Card schema/ML lint: PASS on intake and canonical cards; no missing sections
  or ML hits.
- SPEC validation: PASS, one target and zero failures.
- Build guardrails: PASS with no findings.
- Symbol-scope validation: `BASKET_OK`, zero violations, with XAU and XAG
  declared by the basket manifest.
- Strict target-scoped build gate:
  `D:/QM/reports/framework/21/build_check_20260807_051735.json` (`PASS`,
  strict mode, 0 failures, 0 warnings).
- The gate's single compiler invocation:
  `D:/QM/reports/compile/20260807_051735/summary.csv` (`PASS`, 0 errors,
  0 warnings).
- Compile log:
  `C:/QM/repo/framework/build/compile/20260807_051735/QM5_20260_xauxag-mom-vote.compile.log`.
- EX5 size: 391,294 bytes.
- Setfile risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; generated header build hash
  `6c2ac3aa110c1fb62587c1e0c8027e3d94cc34c8f9b8282b8fa878ac752abc15`.
- Manual smoke/backtest: none.

Artifact SHA-256 values after the Q01/Q02 card-status update:

| Artifact | SHA-256 |
|---|---|
| Source packet | `76A5287B5FBA620F06FE431CAF38C7B75B79C47CCC36E2F6975F60A46FA90AB6` |
| Intake/canonical/build card | `9FEB53A59470949C0E6FA517B8C19D965CFAF59AD299F7D2FAD7608C39591E8D` |
| MQ5 | `7DC847C03517705CA08F3EAF5913885993E595573B3AF4036AD84A745F63BF69` |
| EX5 | `6CCDD1FB00CA421D32017B60550FD8259227A5A897DACC6109A43B755EF1FE3D` |
| SPEC | `1DC3B4C5F36EB37D792C00A982C52D9CC92956C0864DE4B62E0858DF2A3DE69F` |
| Basket manifest | `CA9A9AF068DFD878D5491A1EC6DF7200232CB5DDADB1C63A4932B821EC6AA1BC` |
| Backtest set | `FDE96014114F5CDC8BB95A4E0EEDEEFBF19092194D2E4DCE933454E0F30FF4DF` |

## Q02 Capacity And Enqueue

`farmctl mt5-slots` sampled governed processes at
`2026-08-07T05:19:49+00:00` and found six active factory terminals against the
paced ceiling of seven:

| Terminal | PID | Active phase |
|---|---:|---|
| T1 | 8264 | Q02 |
| T2 | 16856 | Q09 |
| T5 | 19392 | Q02 |
| T7 | 12600 | Q02 |
| T8 | 16576 | Q02 |
| T9 | 20384 | Q09_NEWS |

Only governed factory terminals count toward the paced ceiling. The separate
`C:/QM/mt5/T_Live` and FTMO processes were observed by the read-only sample but
excluded and were not accessed or changed. With governed load at 6/7, the
target-only dry run reported one eligible never-tested item. The single
apply-mode command then reported one Q02 enqueue and no later-phase promotion.

Immediate readback recorded:

- work item: `247fc177-43a3-4bc2-aa66-9a10ed42c151`;
- phase/kind: `Q02` / `backtest`;
- symbol: `QM5_20260_XAU_XAG_MOMVOTE_D1`;
- status: `pending`;
- attempt count: 0;
- claimed by: null;
- created: `2026-08-07T05:20:24+00:00`.

This is an enqueue handoff, not a Q02 screening verdict.

## Safety Boundary

- No dispatch tick, manual backtest, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading and `T_Live` were not touched.
- The portfolio gate and T_Live manifest were not touched.
