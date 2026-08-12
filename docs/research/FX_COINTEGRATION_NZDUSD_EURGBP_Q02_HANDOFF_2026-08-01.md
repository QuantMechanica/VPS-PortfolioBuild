# QM5_20195 NZDUSD/EURGBP Cointegration — Q02 Handoff

Date: 2026-08-01
Branch: `agents/board-advisor`

## Outcome

QM5_20195 is a new, non-duplicate, low-frequency D1 FX basket and is queued
for Q02 as one logical package:

- Logical symbol: `QM5_20195_NZDUSD_EURGBP_COINTEGRATION_D1`
- Q02 work item: `bb538363-c4c2-4899-8b65-ceda04be813b`
- Queue state at handoff: `pending`, attempt count 0
- Build task: `19bb5e5c-eca4-4cfe-bd92-317fa91add5f`, status `done`
- Physical-host setfile: deliberately skipped by auto-enqueue
- Live artifacts: none

The established QM5_12532 and QM5_12533 baskets were not Q02-blocked:
both already passed Q02 and later failed Q05 and Q04 respectively. This work
therefore selected a new pair rather than changing either anchor.

## Selection and Source Boundary

The checked-in sign-aware reproduction of the fixed 66-pair scan ranked
NZDUSD/EURGBP twelfth by OOS net Sharpe. Ranks 10 and 11 were already built
as QM5_20191 and QM5_20193, while exact-pair searches found no prior
NZDUSD/EURGBP or EURGBP/NZDUSD card, EA, or basket manifest.

Frozen scan row:

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| NZDUSD / EURGBP | -0.082879 | 0.720866 | 8.085125% | 21 | -0.101296029 | 116.313 D1 bars |

The negative DEV result, small hedge coefficient, and long half-life are
recorded as adverse priors. They are not a promotion claim. The approved card
combines the OWNER-requested fixed scan lineage with the OWNER-ratified Tier-A
Chan SRC02 pair-trading method. Chan supplies the structural method and makes
no performance claim for this pair.

## Mechanization

- Host/traded leg: `NZDUSD.DWX`, magic `201950000`
- Companion/traded leg: `EURGBP.DWX`, magic `201950001`
- Conversion-history only: `GBPUSD.DWX` and `EURUSD.DWX`; no orders or magics
- Fixed spread: `ln(NZDUSD) - (-0.101296029) * ln(EURGBP)`
- Signal: strictly prior 60-bar closed-D1 z-score
- Entry/exit: `abs(z) > 2.0` / `abs(z) < 0.5`
- Risk stop: `ATR(20, D1) * 2.0` per traded leg
- Package safety: both normalized volumes are preflighted; partial entry and
  orphan states are flattened
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

The USD tester exposed both GBPUSD and EURUSD conversion routes for EURGBP
profit/margin accounting. The final card, manifest, source warmup, SPEC, and
regression test declare all four histories. This is an operational history
contract change only; the pair, beta, signal, and risk model are unchanged.

## Q01 Evidence

- Strategy Card schema lint: PASS, no ML hits
- G0 card lint: PASS; card status `APPROVED`
- Build authorization guard: PASS
- Strict V5 build check: PASS, zero failures and zero warnings
- MetaEditor compile: PASS, zero errors and zero warnings
- SPEC validation: PASS
- Symbol-scope validation: `BASKET_OK`, zero violations, four manifest symbols
- Basket manifest regression suite: 25 PASS
- Magic resolver: 15,378 rows kept, zero dropped under `--keep-obsolete`
- Final EX5 SHA-256:
  `9530f40978fb9a86477ee5ff337d1767979b7a3db6948e797ebf867d9cf6b2c9`
- Final build report:
  `D:\QM\reports\framework\21\build_check_20260801_121152.json`
- Final compile summary:
  `D:\QM\reports\compile\20260801_121152\summary.csv`

Implementation commits are `59c236a41` (initial EA) and `58f7b6e17`
(complete conversion-history contract). The deterministic farm committed the
initial ID/card/magic reservation as `935764c19` and the approved-card history
amendment as part of `bf86eb262`.

## Build-Smoke Evidence and Boundary

A T9 host-symbol pass on the pre-history-amendment binary completed with 100%
real ticks, 259 D1 bars, 24 trades, PF 0.85, 1.44% maximal equity drawdown,
and USD -312.60 net profit. It proves that the two-leg sign-aware entry and
order plumbing execute, but it is not a deterministic final-binary smoke and
is not a Q02 verdict:

- Report:
  `D:\QM\reports\smoke\QM5_20195\20260801_120332\raw\run_01\report.htm`
- Report SHA-256:
  `fc4afd97c08299617ef8a2f03ed667c07a70315b61865485b67809416c189863`

The final binary then encountered terminal-side `EURUSD.DWX history
synchronization error` before tester execution on both T7 and T6. Four bounded
T6 attempts returned `BARS_ZERO` / `INCOMPLETE_RUNS`, with no ONINIT failure
or log bomb. T3 also lacked a configured tester account, and T9's second-run
parser encountered a pre-existing oversized shared tester log. The governed
build recorder therefore converted `framework_error` to sanctioned
`deferred_p2_smoke`, preserved the infrastructure detail, and left Q02 to
synchronize the manifest-declared histories:

- Final smoke summary:
  `D:\QM\reports\smoke\QM5_20195\20260801_121732\summary.json`
- Summary SHA-256:
  `b2ced211095c7b4f3597b83520ea0892cdfbbbb5e3abb25e372deda23dd75ea7`

No additional tester retry is authorized by this handoff. Q02 is the next
governed judge, and the fitted beta must not be swept or rescued.

## Q02 Queue Contract

The queued payload contains:

- Host: `NZDUSD.DWX`, D1
- Basket symbols: `NZDUSD.DWX`, `EURGBP.DWX`, `GBPUSD.DWX`, `EURUSD.DWX`
- Tester account: USD 100,000
- Logical setfile only
- Basket timeout: 450 minutes
- Priority track: true

No portfolio-admission file, portfolio KPI, Q08 contribution record,
T_Live manifest, AutoTrading state, or live setfile was touched.
