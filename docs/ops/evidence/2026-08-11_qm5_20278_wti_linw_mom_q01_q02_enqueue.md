# QM5_20278 WTI Linear-Recency Momentum — Q01 PASS / Q02 Enqueued

Date: 2026-08-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20278_wti-linw-mom` is a new low-frequency outright WTI structural-
trend candidate. It is built, Q01 is `PASS`, and exactly one current-binary
`XTIUSD.DWX` row is `Q02 pending`. The work item is
`50b53e15-f54e-407d-89ee-76dfc758f762`, attempt 0, unclaimed, and has no
verdict. The successful enqueue occurred below the path-anchored factory CPU
ceiling. No dispatch tick, smoke test, or manual backtest was run.

## Edge And Non-Duplicate Boundary

At each genuine `XTIUSD.DWX` broker-month transition, the EA reconstructs
thirteen consecutive completed WTI month-end closes `C[0]..C[12]`, oldest to
newest. It forms twelve adjacent chronological log returns
`r[i] = ln(C[i+1] / C[i])`, assigns weights `w[i] = i+1`, and divides the
weighted sum by exactly 78. A positive mean buys, a negative mean sells, and
an exact-zero or invalid state consumes the month flat. The old package closes
at the next month transition before any replacement. A frozen
`3.5 * ATR(20,D1)` hard stop and forty-day stale exit protect the package.

The deterministic pre-allocation check scanned 4,343 EA-registry rows and 454
cards. It found no exact duplicate and surfaced three expected same-source
fuzzy matches: the WTI median-return, middle-eight trimmed-mean, and two-tail
Winsorized-mean cards. Those systems sort the twelve returns and discard
chronology. This rule never sorts and gives every adjacent return a unique
oldest-to-newest weight. The quarterly vote discards magnitude, the WTI OLS
card fits log-price levels with an `R^2` gate, and the index MAC(5) card is a
four-day SP500 contrarian rule with weights `4,3,2,1`.

The reference vectors prove that chronology is load-bearing: reversing the
same return multiset leaves the cumulative return unchanged but flips the
linear-weighted signal. A separate vector makes this estimator negative while
the existing median, trimmed-mean, and Winsorized estimators are positive. The
thirteen endpoints, twelve adjacent intervals, return orientation, weight
vector `1..12`, total 78, symmetric trend mapping, monthly attempt, and
renewal lifecycle are jointly fixed.

WTI adds a crude-oil carrier distinct from the current XAU, SP500, NDX, and
XNG instruments. A different carrier and estimator do not prove low or
negative realized correlation; Q09 alone may establish portfolio correlation
if the candidate survives the earlier gates.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-LINW-2026/source.md`. Its complete-read parent
is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The governed 23-page paper receipt has PDF
SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`
and explicitly includes NYMEX WTI crude in the commodity-futures universe.

The paper supports testing monthly own-price trend in WTI. It does not specify
linear recency weights, a Darwinex continuous CFD, ATR stop, spread cap, or
lifecycle. Those are explicit QM mechanization choices. No source performance,
CFD equivalence, or portfolio-correlation result is imported. Durable G0
authorization is
`decisions/2026-08-11_qm5_20278_wti_linw_mom_g0.md`.

Reputable-source checks R1-R4 pass: one named peer-reviewed DOI record with a
complete governed read and durable hash; exact mechanical rules; a registered
WTI D1 route; and deterministic native arithmetic with no ML, trained output,
banned signal indicator, external runtime feed, grid, martingale, scale-in,
or pyramid.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20278` / `wti-linw-mom` /
  `MOP-TSMOM-2012_XTI_LINW12_S26`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202780000`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Resolver generation: 15,852 rows kept and zero dropped; the target tuple was
  verified exactly once after generation.
- Strict compile: `D:/QM/reports/compile/20260811_072519/summary.csv`, PASS
  with zero errors and zero warnings.
- Strict compile log:
  `C:/QM/repo/framework/build/compile/20260811_072519/QM5_20278_wti-linw-mom.compile.log`.
- Targeted build check:
  `D:/QM/reports/framework/21/build_check_20260811_072518.json`, PASS with
  zero failures and zero warnings.
- P1 artifact validation:
  `D:/QM/reports/pipeline/QM5_20278/P1/P1_QM5_20278_result.json`, PASS.
- Independent statistic reference test:
  `framework/EAs/QM5_20278_wti-linw-mom/docs/test_linear_weight_reference.py`,
  PASS for positive, negative, exact-zero, chronology-reversal, robust-
  location divergence, and direct-ramp vectors.
- Card schema/ML lint, G0 lint, build-prerequisite guard, SPEC validation, and
  canonical/build-card identity: PASS.
- Generated setfile header build hash:
  `085e5a6334b8e4d3a986cf9c126617a9a5938a968f2d7c955f27cfdc4ec0faf7`.
- Manual smoke/backtest: none.

Artifact SHA-256 values at enqueue:

| Artifact | SHA-256 |
|---|---|
| Bounded source packet | `48AD8D244209C16B0FEFBC3999776DD651E025A61C17D6E78C5EC1DC4FC24618` |
| Canonical/build card | `D3C267121116EE252FA16850961BC3F5AE483E59DFD809A4818F29745B94D83B` |
| MQ5 | `96BB31D46279A222D0650370DB5EB3AEE06672A4202BE513AB94C0B9DD8C52FC` |
| EX5 | `92BC65522B3250BBB37088B7F6E731AC6E09B87B23A47A4EB5D44929AB9A9934` |
| SPEC | `E2659886507F3504FA73E64DC9F1170D6BDF03F943EF052F21365DB0B30D181B` |
| Backtest set | `613F99203383C025F2BD578BFCFA521596FB45E94BB54703CC06BA094F9503D3` |
| Reference test | `E693699801BC67499AB445C04F59E1CC4021BFBA114322D63FEAEE4DDB7E4C80` |

## Q02 Capacity And Enqueue Evidence

The first path-anchored sample at `2026-08-11T07:27:51+00:00` found five
executing factory terminals: T2, T3, T6, T7, and T10. This was below the
ceiling of seven. The machine-wide `terminal64_running_count` was seven only
because the same inventory separately observed `C:/QM/mt5/T_Live` and an FTMO
terminal; both are outside the governed T1-T10 count and were not touched.

The non-mutating sweep selected exactly one priority-track never-tested row
for `QM5_20278 / XTIUSD.DWX` and no stranded rows. The first apply attempt
returned `factory mutation lock busy` and made no change. The lock disappeared
without intervention. A fresh immediate sample at
`2026-08-11T07:29:50+00:00` found three executing factory terminals—T3, T7,
and T10—against the ceiling of seven, while the target-only readback still
returned zero work items.

The bounded apply retry at `2026-08-11T07:29:58+00:00` enqueued exactly one
never-tested priority-track row. Sweep evidence is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`; its internal
`generated_at` is `2026-08-11T07:29:58+00:00`, `apply=true`, and its selected
setfile is
`QM5_20278_wti-linw-mom_XTIUSD.DWX_D1_backtest.set`.

Immediate `farmctl work-items --ea QM5_20278` readback returned:

| Field | Value |
|---|---|
| Work item | `50b53e15-f54e-407d-89ee-76dfc758f762` |
| Phase | `Q02` |
| Kind | `backtest` |
| Symbol | `XTIUSD.DWX` |
| Status | `pending` |
| Attempt | 0 |
| Claimed by | none |
| Verdict | none |

This is an enqueue handoff, not a Q02 screening verdict.

## Commits Before This Closing Evidence

- `724a8f020` — OWNER mission authorization and exact G0 decision.
- `8918ae4e6` — bounded source packet plus approved/intake cards.
- `c8fddccc9` — deterministic EA-ID reservation.
- `07bc8bd87` — target SPEC scaffold.
- `9dbebf1db` — slot-0 WTI magic allocation and resolver generation.
- `774b21895` — EA source, EX5, reference test, fixed-risk setfile, Q01
  evidence bindings, and Q02 status.

## Safety Boundary

- No dispatch tick, manual backtest, smoke test, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled; `T_Live` was not accessed or changed.
- The portfolio gate and T_Live manifest were not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from Q01 or the Q02 enqueue.
