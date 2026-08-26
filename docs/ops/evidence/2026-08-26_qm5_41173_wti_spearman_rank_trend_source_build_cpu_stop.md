# QM5_41173 WTI Spearman Rank Trend Source Build And CPU Stop

Date: 2026-08-26

Branch: `agents/board-advisor`

EA: `QM5_41173_wti-mspearman-tr`

Outcome: `SOURCE BUILD COMMITTED; COMPILE QUEUED_ACTIVATION_HELD; Q01 PENDING; Q02 NOT_ENQUEUED_CPU_CEILING`

## New commodity/energy candidate

`QM5_41173` is a low-frequency, symmetric direct-WTI structural trend
candidate on exact `XTIUSD.DWX` D1. At the first executable bar of a new
broker month it reconstructs the latest close from each of the immediately
prior thirteen completed consecutive months and assigns strict no-tie price
ranks oldest to newest.

For price ranks `R[i]` and fixed calendar ranks `i+1`, it computes
`D=sum((R[i]-(i+1))^2)` and the exact Spearman integer score `T=364-D`.
It buys WTI at `T>=104`, sells at `T<=-104`, and consumes weaker or malformed
months flat. This is exactly `abs(rho)>=2/7` without floating runtime
arithmetic, tie averaging, p-values, or an endpoint fallback.

Each accepted position uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, and exact next-month closure with a
forty-day stale repair. It has one attempt and at most one owned position per
broker month. Only one backtest preset exists.

The direct crude-oil carrier is absent from the stated certified XAU, SP500,
NDX, and XNG book. The global price-rank/time-rank displacement is also
mechanically distinct from existing WTI Mann-Kendall pair signs, Cox-Stuart
lag pairs, record events, Bartels adjacent distances, turning points, and
Pettitt central change-point location. These are design facts only. Unchanged
Q09 owns the first realized portfolio-correlation verdict.

## Reputable source and non-duplicate boundary

Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`, supplies complete-read
peer-reviewed monthly own-price continuation lineage and explicit WTI
membership. Spearman (1904), *The American Journal of Psychology* 15(1), DOI
`10.2307/1412159`, supplies the named rank-correlation record. Complete pinned
R Core `stats::cor` source and manual files at commit
`7344a2d9d96b3c2b997535d3abc8c3a44af16e82` supply the exact operational
rank-transform definition. The thirteen-endpoint threshold and continuous-CFD
rule are a disclosed QM mechanization; no source performance transfers.

The pre-allocation checker scanned 4,672 registry identities, 1,323 cards,
and 45 Strategy Wiki nodes and returned clean. Four fixed counterexample rank
paths distinguish this rule from the Mann-Kendall and Pettitt neighbors. The
receipt is
`artifacts/qm5_wti_mspearman_tr_preallocation_dedup_20260826.json`, SHA-256
`B7296C4BDEEC4624F25909AD9AD48A1F0020D57955676B84819855373EAD91F8`.

## Durable commit trail

- source approval and reproducible retrieval evidence: `86bde74ea`;
- deterministic identity, G0 decision, and approved card: `b072d21a3`; and
- governed magic, resolver, source, SPEC, reference suite, EA-local card, and
  one fixed-risk D1 backtest preset: `63c1aad5d`.

The queued MQ5 SHA-256 is
`6B6C746DBB51374FB77A0E838F5C537F7200894A64C74E4979E2D5E832199ED3`.
The unbound pre-compile setfile SHA-256 is
`87192D94473654A23E02BD125DC40E0AC70D31A3E7078D9A6E4005C61DC08BA4`;
its `build_hash` remains `PENDING_COMPILE` until governed compilation. The
canonical card and EA-local copy are byte-identical at SHA-256
`40A433746360469EA1292E49DD30B817857C89F6F24FD9A15D69093B455886AE`.

## Source-level validation

The target-only deterministic reference suite passed 9/9 tests. It covers the
strict rank permutation, D/T identity and invariants, exact inclusive boundary,
long/short symmetry, all 13! rank orders and the locked density count, four
neighbor-discriminating fixtures, consecutive month keys, fixed-risk
source/set markers, exact card-copy identity, and absence of a live preset.

The skill build prerequisite guard, V5 guardrails, SPEC validator,
single-symbol leak validator, card schema/prohibited-input lints, and magic
resolver dry-run passed. Static build hardening reported no failures; its
legacy card finder emitted warnings because it does not descend into the
canonical `cards/approved` store, while both the approved card and byte-exact
EA-local copy were independently linted. The repository-wide registry audit
also remains nonzero on pre-existing unrelated inventory defects; the
target-specific registry and zero-collision allocation checks passed.

No strict compile, EX5, full build-check, Q01 PASS, smoke, backtest, economic
result, or decorrelation result is claimed by these source-level checks.

## Governed compile and Q02 blockers

The direct strict compile failed safely because MT5 `terminal64.exe` processes
were active. The failure class was `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no
retry, include-mirror bypass, terminal control, or process stop occurred.

The mandated governed compile command created utility work item
`71ef9990-199b-4381-b43b-e3c36045b4f5`. At the last read it was the sole work
item for `QM5_41173`, pending, verdict-free, and held under
`COMPILE_EA_WORKER_ROLLOUT_PENDING`. Therefore no EX5 or Q01 PASS exists.

Before any target-only Q02 enqueue, five fresh whole-host CPU samples at
four-second spacing were:

| Sample UTC | CPU |
|---|---:|
| `2026-08-26T21:43:25.1534968Z` | 95.0% |
| `2026-08-26T21:43:29.4515497Z` | 99.0% |
| `2026-08-26T21:43:33.7209476Z` | 96.0% |
| `2026-08-26T21:43:38.0311047Z` | 93.0% |
| `2026-08-26T21:43:42.3046305Z` | 99.0% |

Average CPU was 96.4 percent and maximum CPU was 99.0 percent, exceeding the
97 percent backtest hard ceiling. The same capacity snapshot observed seven
`terminal64` and five `metatester64` processes. The mission's explicit CPU
stop therefore fired. No Q02 apply, manual tester, smoke, or dispatcher tick
was attempted. Q02 is blocked independently by both absent Q01 evidence and
the measured CPU ceiling.

## Safe next action

After the separately authorized compile-worker rollout releases the compile
hold, let the governed worker consume the exact queued source. Require strict
compile PASS with zero errors and warnings, a non-empty source-fresh EX5,
final setfile binding, and Q01 PASS. Only after CPU is freshly below the
ceiling, repeat target-only work-item/dedup checks and enqueue exactly one
`XTIUSD.DWX` D1 Q02 row.

No terminal process was started or stopped. AutoTrading, `T_Live`, the live
manifest, portfolio gate, portfolio membership, thresholds, and correlation
policy were untouched.

Machine-readable evidence:
`artifacts/qm5_41173_compile_handoff_20260826T214427Z_board_advisor.json`.
