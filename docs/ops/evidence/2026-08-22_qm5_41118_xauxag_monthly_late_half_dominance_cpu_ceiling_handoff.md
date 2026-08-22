# QM5_41118 XAU/XAG monthly late-half dominance reversion — CPU-ceiling handoff

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41118_xauxag-mlatehalf-dom-rv`

Outcome: **SOURCE BUILD COMMITTED; CPU CEILING HIT; Q01 PENDING; Q02 NOT ENQUEUED**

## Edge delivered

QM5_41118 is one low-frequency, opposite-leg gold/silver relative-value
package. At the first synchronized D1 boundary of a new broker month, it
reconstructs the two immediately preceding consecutive completed months.
Each month must contain 17 through 23 timestamp-identical `XAUUSD.DWX` and
`XAGUSD.DWX` close pairs.

Let `P` be the parent month's chronological final log ratio and let
`Q[0]...Q[n-1]` be the newest completed month's chronological log ratios. With
`h=floor(n/2)`, the exhaustive early and late returns are `Q[h-1]-P` and
`Q[n-1]-Q[h-1]`. The package trades only when the late half has strictly
greater absolute magnitude. A positive late half is faded with SELL XAU / BUY
XAG; a negative late half is faded with BUY XAU / SELL XAG. Equality, zero,
non-dominance, or invalid history consumes the month flat.

The two legs target equal absolute USD notionals, cap aggregate frozen-stop
risk at one `RISK_FIXED=1000` budget, and normally exit at the next broker
month. This is a distinct structural carrier and rule from the certified
outright XAU/SP500/NDX/XNG book, but paired construction does not prove market
neutrality, profitability, or decorrelation. Q09 alone owns any realized
portfolio finding.

## Reputable source and non-duplicate boundary

The governed packet is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MLATEHALF-DOM-RV-2026/source.md`.
Its lineage is Schweikert (2018), *Journal of Banking & Finance* 88, 44-51,
DOI `10.1016/j.jbankfin.2017.11.010`; Yaya, Vo, and Olayinka (2021),
*Resources Policy* 72, 102045, DOI `10.1016/j.resourpol.2021.102045`; and CME
Group's *Gold & Silver Ratio Spread*. These sources support testing a
state-dependent gold/silver relation and its intermarket ratio carrier. The
completed-month half partition, strict late-half dominance, contrarian side,
CFD mapping, fixed risk, performance, and correlation are disclosed QM
hypotheses.

The fail-closed pre-allocation check scanned 4,615 registry identities, 1,286
cards, and 45 Strategy-Wiki nodes without an exact collision. The
post-allocation check scanned 4,616 identities, 1,286 cards, and 45 Wiki nodes;
only the expected QM5_41118 self-hits remained.

The load-bearing rule is not QM5_41113's two-half sign agreement,
QM5_41116's three-block vote, QM5_41112's daily-sign breadth, QM5_41117's
direct-WTI continuation, QM5_12567's XNG RSI2 oscillator, or a rolling
ratio-center/scale/OLS/tail estimator. It compares the magnitudes of exactly
two exhaustive within-month relative-return blocks and fades only the strict
late-half dominant state.

## Deterministic identity and commits

| Stage | Commit |
|---|---|
| source approval and pre-allocation receipt | `3da399186` |
| bounded reputable-source extraction | `af92247db` |
| atomic EA-ID reservation | `ad481dc84` |
| approved G0 card and post-allocation receipt | `ed1b660cb` |
| governed two-leg magic allocation and resolver regeneration | `68b2bee7b` |
| EA source, SPEC, basket manifest, reference suite, and fixed-risk set | `40c8f0341` |

The exact identities are slot 0 `XAUUSD.DWX` / magic `411180000` and slot 1
`XAGUSD.DWX` / magic `411180001`, both D1. The logical tester symbol is
`QM5_41118_XAU_XAG_MLATEHALF_DOM_RV_D1`.

## Source-level validation

- Strategy Card schema/G0 lint and canonical approval: PASS.
- Approved card, EA registry identity, directory slug, active magic rows, and
  resolver: PASS.
- Deterministic reference suite: 12 tests PASS. Coverage includes both package
  directions; opposed early/late signs; equality, zero, and non-dominance;
  17/20/23-session floor splits and exhaustive path coverage; 16/24 rejection;
  asynchronous, malformed, current-month, and nonconsecutive history; parent
  anchor orientation; durable attempt state; lifecycle; joint fixed-risk
  sizing; static source markers; manifest/set locking; and card-copy identity.
- SPEC validator: PASS.
- Build guardrails: PASS for source and set.
- Symbol-scope validator: `BASKET_OK`, zero violations.
- Approved and EA-local cards are byte-identical at SHA-256
  `B1CF9556121FD3F3F6DE3FB96468818EAE3E3425678A2EF0A6AAAB6ACE3A447B`.

The sole set is backtest-only and locks `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`. It remains deliberately unbound with
`build_hash=pending` until strict compile/Q01.

## CPU-ceiling stop

A fresh five-sample whole-host `Processor(_Total)` check at
`2026-08-22T19:30:21Z` observed `100.00`, `100.00`, `100.00`, `99.90`, and
`99.95` percent CPU: average `99.97`, maximum `100.00`. Seven path-anchored
factory `terminal64.exe` processes and seven active `metatester64.exe`
processes were present. This exceeds the paced-fleet ceiling of 97 percent and
is the mission's binding stop condition.

No strict compile was attempted, no EX5 exists, and Q01 remains pending. No
compile work item, Q02 preview, Q02 work item, smoke/backtest, dispatcher tick,
terminal reservation, process stop, worker action, or queue mutation was made
after the ceiling was observed.

## Safe continuation and safety boundary

When sustained capacity is below the ceiling, run the canonical strict compile
and require zero errors/warnings, a non-empty EX5, build-check PASS, and final
set binding. Only after Q01 passes should a fresh capacity check permit exactly
one logical-basket Q02 enqueue. Q02 must retire the baseline below five
completed packages per full post-warm-up year rather than modify the rule.

No AutoTrading action, live/deploy artifact, `T_Live` mutation,
portfolio-gate change, portfolio admission, correlation waiver, or
decorrelation claim occurred. `T_Live` was visible only in the read-only
process inventory and was not touched.

Machine-readable companion:
`artifacts/qm5_41118_source_build_q02_cpu_ceiling_handoff_20260822T193021Z_board_advisor.json`.
