# QM5_41116 XAU/XAG monthly three-block vote source build and CPU-ceiling handoff

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41116_xauxag-mthirdvote-rv`

Outcome: `SOURCE BUILD COMMITTED; CPU CEILING HIT; Q01 PENDING; Q02 NOT ENQUEUED`

## New commodity sleeve candidate

QM5_41116 is one low-frequency, opposite-leg gold/silver relative-value
package. At the first synchronized D1 boundary of a new broker month, it
reconstructs the two immediately preceding consecutive completed months.
Both require 17 through 23 timestamp-identical `XAUUSD.DWX` and `XAGUSD.DWX`
close pairs.

Let `P` be the parent month's chronological final log ratio and let
`Q[0]...Q[n-1]` be the newest completed month's chronological log ratios. With
`a=floor(n/3)` and `b=floor(2n/3)`, the exhaustive blocks are `Q[a-1]-P`,
`Q[b-1]-Q[a-1]`, and `Q[n-1]-Q[b-1]`. A strict positive two-of-three majority
is faded with SELL XAU / BUY XAG; a strict negative majority is faded with BUY
XAU / SELL XAG. Zero abstains. Magnitude and full-month endpoint agreement do
not alter the vote.

The package targets equal absolute notionals, caps aggregate frozen-stop risk
at one `RISK_FIXED=1000` budget, and normally exits at the next broker month.
This carrier and mechanic are different from the certified outright
XAU/SP500/NDX/XNG book, but neither paired construction nor source lineage
proves profitability, neutrality, or decorrelation. Q09 alone owns any
realized portfolio finding.

## Reputable source and non-duplicate boundary

The governed source packet is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MTHIRDVOTE-RV-2026/source.md`.
Its Tier-A lineage is Schweikert (2018), *Journal of Banking & Finance* 88,
44-51, DOI `10.1016/j.jbankfin.2017.11.010`; Yaya, Vo, and Olayinka (2021),
*Resources Policy* 72, 102045, DOI `10.1016/j.resourpol.2021.102045`; and CME
Group's *Gold & Silver Ratio Spread*. The papers and exchange material support
testing a state-dependent gold/silver relationship and the intermarket ratio
carrier. The floor-third vote, contrarian side, CFD mapping, fixed risk,
performance, and correlation are disclosed QM hypotheses.

The fail-closed pre-allocation check scanned 4,612 registry identities, 1,284
cards, and 45 Strategy-Wiki nodes. It found no exact collision and one fuzzy
family neighbor, QM5_41112, which manual semantic review separated. The
post-allocation scan checked 4,613 identities and 1,285 cards; only the newly
reserved QM5_41116 self-hits remained.

The load-bearing rule is not QM5_41112's daily-sign breadth plus endpoint
agreement, QM5_41113's two-half unanimity, QM5_41115's direct-WTI continuation,
QM5_20260's cross-sectional 1/3/12-month momentum vote, or any rolling
center/scale/OLS/tail estimator. It accepts one opposing cumulative block,
votes exactly three exhaustive within-month relative-return blocks, and takes
the inverse equal-notional two-leg side.

## Deterministic identity and commits

| Stage | Commit |
|---|---|
| source approval and pre-allocation receipt | `d853ac635` |
| bounded reputable-source extraction | `8da1fe0e4` |
| atomic EA-ID reservation | `3bd9a13a9` |
| approved G0 card and post-allocation receipt | `cdc36f894` |
| governed two-leg magic allocation and resolver regeneration | `818027fab` |
| EA source, SPEC, basket manifest, reference suite, and fixed-risk set | `2fe44b801` |

The exact identities are slot 0 `XAUUSD.DWX` / magic `411160000` and slot 1
`XAGUSD.DWX` / magic `411160001`, both D1.

## Source-level validation

- Card schema lint, G0 prohibited-method lint, and canonical approval: PASS.
- Approved card, EA registry identity, directory slug, and both active magic
  rows: PASS.
- Independent reference suite: 12 tests plus 6 majority-permutation subtests
  PASS. Coverage includes both pair directions, every strict two-of-three
  sign permutation, endpoint-opposed magnitude, zero abstention, all
  17/20/23-session floor partitions, exhaustive block coverage, 16/24
  rejection, asynchronous/malformed/nonconsecutive/current-month history,
  parent-final orientation, attempt persistence, lifecycle, equal-notional
  joint risk, static MQ5 markers, manifest, set, and card-copy identity.
- SPEC validator: PASS.
- Build guardrails: PASS for both source and set.
- Symbol-scope validator: `BASKET_OK`, zero violations.
- Approved and EA-local cards are byte-identical at SHA-256
  `E07395ABE7C50FA10EA73397E9D26A4CB76F9D1A4A07199DBEFF4DEB1D144641`.

The sole set is backtest-only and locks `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`. It remains deliberately unbound with
`build_hash=pending` until strict compile/Q01. No live, demo, shadow, stress,
or optimization set exists.

## CPU-ceiling stop

The fresh compile/Q02 boundary check observed seven paced-fleet
`terminal64.exe` slots and five active `metatester64.exe` processes while the
whole-host processor load was 100 percent. A second read-only snapshot roughly
two minutes later remained at 100 percent and showed seven active metatesters.
This exceeds the current 97-percent paced-fleet ceiling and is the mission's
binding stop condition.

No strict compile was attempted, no EX5 exists, and Q01 remains pending. No
compile work item, Q02 preview, Q02 work item, smoke/backtest, dispatcher tick,
terminal reservation, process stop, worker action, or queue mutation was made
after the ceiling was observed.

## Safe continuation and safety boundary

When capacity is below the ceiling, run the canonical strict compile and
require zero errors/warnings, a non-empty EX5, build-check PASS, and final set
binding. Only after Q01 passes should a fresh capacity check permit exactly one
logical-basket Q02 enqueue.

No AutoTrading action, live/deploy artifact, `T_Live` mutation, portfolio-gate
change, portfolio admission, correlation waiver, or decorrelation claim
occurred. `T_Live` was visible only in the read-only process inventory and was
not touched.

Machine-readable companion:
`artifacts/qm5_41116_source_build_q02_cpu_ceiling_handoff_20260822T171340Z_board_advisor.json`.
