# QM5_41169 WTI Foster-Stuart Record Trend Source Build And CPU Stop

Date: 2026-08-26

Branch: `agents/board-advisor`

EA: `QM5_41169_wti-foster-record-tr`

Outcome: `SOURCE BUILD COMMITTED; COMPILE QUEUED_ACTIVATION_HELD; Q01 PENDING; Q02 NOT_ENQUEUED_CPU_CEILING`

## New commodity/energy candidate

`QM5_41169` is a low-frequency, symmetric direct-WTI structural trend
candidate on exact `XTIUSD.DWX` D1. At the first executable bar of a new
broker month it reconstructs the latest close from each of the immediately
prior thirteen completed consecutive months. Starting with the oldest close
as both frontiers, each later close is classified as a strict new upper
record, strict new lower record, or neutral observation. Equality is neutral
and all twelve classifications must be conserved.

The EA buys at `upper-lower >= 2`, sells at `upper-lower <= -2`, and consumes
the month flat otherwise. Each accepted position uses `RISK_FIXED=1000`,
`RISK_PERCENT=0`, a frozen `3.5*ATR(20,D1)` hard stop, no target, and exact
next-month closure with a forty-day stale repair. It has one attempt and at
most one owned position per broker month.

The direct crude-oil carrier differs from the certified XAU, SP500, NDX, and
XNG book, while its forward record-frontier path statistic differs from
endpoint, fitted-slope, Mann-Kendall, Cox-Stuart paired-sign, quarterly-vote,
and incumbent XNG pullback mechanics. These are design facts only. Unchanged
Q09 owns the first realized portfolio-correlation verdict.

## Reputable source and non-duplicate boundary

Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`, supplies peer-reviewed monthly
own-price continuation lineage and explicit WTI membership. Foster and
Stuart (1954), *JRSS B* 16(1), 1-22, DOI
`10.1111/j.2517-6161.1954.tb00143.x`, supplies record-count trend lineage.
The complete relevant files at public `RecordTest` commit
`463cca629cec54ed58dfe0f03140d29be6c8f2aa`, associated with the peer-reviewed
JSS 106(5) package, supply strict forward upper/lower definitions and the
unweighted record difference. The exact thirteen-endpoint threshold-two CFD
rule is a disclosed QM mechanization; no source performance transfers.

The pre-allocation checker scanned 4,668 registry identities, 1,319 cards,
and 45 Strategy Wiki nodes and returned clean. Manual functional vectors
separate the rule from the neighboring WTI endpoint, Mann-Kendall,
Cox-Stuart, quarterly-vote, Spearman, and slope families. The receipt is
`artifacts/qm5_wti_foster_record_tr_preallocation_dedup_20260826.json`.

## Durable commit trail

- source approval and reproducible retrieval evidence: `97221b5cc`;
- deterministic identity, G0 decision, and approved card: `633eddf81`; and
- governed magic, resolver, source, SPEC, reference suite, EA-local card, and
  one fixed-risk D1 backtest preset: `4a224d35d`.

The queued MQ5 SHA-256 is
`824DE3B7364FD65FA44649E6D5DC276AD571A0AEBB53D5C1598C5FAB4BCC75DF`.
The unbound pre-compile setfile SHA-256 is
`6CD3DD2B72C339AFD228E5FE4AC3E7C501037D74FBC42CF9310FFDE5474DCF6B`;
its `build_hash` remains `PENDING_COMPILE` until governed compilation. The
canonical card and EA-local copy are byte-identical at SHA-256
`754B82A0E72FECDC5EE3DEE11A704CA11A5E540B8C9EFAD8858B23E54080813A`.

## Source-level validation

The target-only deterministic reference suite passed 8/8 tests. It covers
monotone long/short states, strict equality-neutral behavior, symmetric
threshold two, count conservation, malformed inputs, thirteen consecutive
month keys and year rollover, two locked non-duplicate vectors, fixed-risk
source/set markers, and an exact dynamic-programming enumeration of all
`13!` distinct-rank permutations. Exactly 2,963,909,390 of 6,227,020,800
permutations qualify, a non-empirical density of 47.5975508224 percent.

The build prerequisite guard, V5 guardrails, SPEC validator, single-symbol
leak validator, and both card schema/prohibited-ML lints passed. No strict
compile, EX5, full build-check, Q01 PASS, smoke, backtest, economic result, or
decorrelation result is claimed by these source-level checks.

## Governed compile and Q02 blockers

The direct strict compile and build-check preflight each failed safely because
MT5 `terminal64.exe` processes were active. The failure class was
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no retry, include-mirror bypass,
terminal control, or process stop occurred.

The mandated governed compile command created utility work item
`4a6e89aa-9405-4e9b-b292-bae442b52015`, bound to the MQ5 hash above. At the
last successful read it was pending, verdict-free, and held under
`COMPILE_EA_WORKER_ROLLOUT_PENDING`. The separately authorized worker restart
ceremony was not bypassed. Therefore no EX5 or Q01 PASS exists.

Before any target-only Q02 enqueue, five fresh whole-host CPU samples at
four-second spacing were:

| Sample UTC | CPU |
|---|---:|
| `2026-08-26T15:45:35.3569236Z` | 100% |
| `2026-08-26T15:45:39.8538493Z` | 100% |
| `2026-08-26T15:45:44.1337069Z` | 97% |
| `2026-08-26T15:45:48.4523047Z` | 99% |
| `2026-08-26T15:45:52.7275508Z` | 100% |

Average CPU was 99.2 percent and maximum CPU was 100 percent, meeting or
exceeding the 97 percent backtest hard ceiling. The mission's explicit CPU
stop therefore fired. No Q02 apply, manual tester, smoke, or dispatcher tick
was attempted. Q02 is blocked independently by both absent Q01 evidence and
the measured CPU ceiling.

## Safe next action

After the separately authorized fleet-worker restart releases the compile
hold, let the governed worker consume the exact queued source. Require strict
compile PASS with zero errors/warnings, a non-empty source-fresh EX5, final
setfile binding, and Q01 PASS. Only after CPU is freshly below the ceiling,
repeat target-only work-item/dedup checks and enqueue exactly one
`XTIUSD.DWX` D1 Q02 row.

No terminal process was started or stopped. AutoTrading, `T_Live`, the live
manifest, portfolio gate, portfolio membership, thresholds, and correlation
policy were untouched.

Machine-readable evidence:
`artifacts/qm5_41169_compile_handoff_20260826T154553Z_board_advisor.json`.
