# QM5_20279 WTI Exponential-Recency Momentum — Q01 PASS / Q02 Enqueued

Date: 2026-08-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20279_wti-expw-mom` is a new low-frequency outright WTI structural-
trend candidate. It is built, Q01 is `PASS`, and exactly one current-binary
`XTIUSD.DWX` row is `Q02 pending`. The work item is
`32cbb0ce-42eb-498a-b8da-2a0115c78494`, attempt 0, unclaimed, and has no
verdict. The successful enqueue occurred below the path-anchored factory CPU
ceiling. No dispatch tick, smoke test, or manual backtest was run.

## Edge And Non-Duplicate Boundary

At each genuine `XTIUSD.DWX` broker-month transition, the EA reconstructs
thirteen consecutive completed WTI month-end closes `C[0]..C[12]`, oldest to
newest. It forms twelve adjacent chronological log returns, gives return `i`
age `11-i`, assigns weight `2^(-age/3.0)`, and divides the weighted sum by the
twelve-weight total. A positive mean buys, a negative mean sells, and an exact-
zero or invalid state consumes the month flat. The old package closes at the
next month transition before any replacement. A frozen
`3.5 * ATR(20,D1)` hard stop and forty-day stale exit protect the position.

The deterministic pre-allocation check scanned 4,344 EA-registry rows and 455
cards. It found no exact identity and no fuzzy match above threshold.
`QM5_20278` is the nearest chronological-return neighbor, but its integer
weights `1..12` do not have a constant decay rate. QM5_20279 instead fixes base
two and a three-month half-life: newest weight one, then one-half, one-quarter,
and one-eighth at ages three, six, and nine. Median, trimmed, and Winsorized
cards sort or cap returns; quarterly vote discards magnitude; regression,
rank, pairwise-slope, path-efficiency, and high-low cards use different state
objects.

The independent reference vectors prove that chronology is load-bearing:
reversing the same return multiset leaves cumulative return unchanged but flips
the exponential signal. A separate vector makes this estimator negative while
the existing linear, median, trimmed-mean, and Winsorized estimators remain
positive. The thirteen endpoints, twelve adjacent intervals, return
orientation, age map, base two, three-month half-life, normalization, symmetric
direction, monthly attempt, and renewal lifecycle are jointly fixed.

WTI adds a crude-oil carrier distinct from the current XAU, SP500, NDX, and
XNG instruments. A different carrier and estimator do not prove low or
negative realized correlation; Q09 alone may establish portfolio correlation
if the candidate survives the earlier gates.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-EXPW-2026/source.md`. Its complete-read parent
is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The governed 23-page paper receipt has PDF
SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`
and explicitly includes NYMEX WTI crude in the commodity-futures universe.

The paper supports testing monthly own-price trend in WTI. It does not specify
exponential recency weights, a three-month half-life, a Darwinex continuous
CFD, ATR stop, spread cap, or lifecycle. Those are explicit QM mechanization
choices. No source performance, CFD equivalence, or portfolio-correlation
result is imported. Durable G0 authorization is
`decisions/2026-08-11_qm5_20279_wti_expw_mom_g0.md`.

Reputable-source checks R1-R4 pass: one named peer-reviewed DOI record with a
complete governed read and durable hash; exact mechanical rules; a registered
WTI D1 route; and deterministic native arithmetic with no ML, trained output,
banned signal indicator, external runtime feed, grid, martingale, scale-in,
or pyramid. The public-source reader was not invoked because the OWNER mission
supplied no URL and the source-reader contract does not allow inventing one.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20279` / `wti-expw-mom` /
  `MOP-TSMOM-2012_XTI_EXPW12_S27`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202790000`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Resolver generation: 15,870 rows kept and zero dropped; the target tuple was
  verified exactly once after generation.
- Strict compile: `D:/QM/reports/compile/20260811_111716/summary.csv`, PASS
  with zero errors and zero warnings.
- Strict compile log:
  `C:/QM/repo/framework/build/compile/20260811_111716/QM5_20279_wti-expw-mom.compile.log`.
- Targeted build check:
  `D:/QM/reports/framework/21/build_check_20260811_111759.json`, PASS with
  zero failures and zero warnings.
- P1 artifact validation:
  `D:/QM/reports/pipeline/QM5_20279/P1/P1_QM5_20279_result.json`, PASS.
- Independent statistic reference test:
  `framework/EAs/QM5_20279_wti-expw-mom/docs/test_exponential_weight_reference.py`,
  PASS for half-life anchors, positive, negative, exact-zero, chronology-
  reversal, neighbor-estimator divergence, and direct-ramp vectors.
- Card schema/ML lint, G0 lint, build-prerequisite guard, SPEC validation, and
  canonical/build-card identity: PASS.
- Generated setfile header build hash:
  `4e60ca04da6ad5097fd291fac676bf72cf218bc2341bbdbab9c03ea5ed9670eb`.
- Manual smoke/backtest: none.

Artifact SHA-256 values at enqueue:

| Artifact | SHA-256 |
|---|---|
| Bounded source packet | `144B72109066D6330875406DAE332A7CFE0C7B878351B75B66B0AA7068459D7C` |
| Canonical/build card | `B97A5EDD8532DD8489E4D913E4C7F29E7390B3D2CB2CB372A5536274BFD6FCB9` |
| MQ5 | `E748ACD7A3FD9378ACC2BE701E00173D791E59165B8935453C68584B5DD2A2E4` |
| EX5 | `13CBEAFD859A4085F1A57B04F29DFB03AD7E1A45454907549028EF5DDCBF1087` |
| SPEC | `B7B45E5283AD0DBE4116CC3FA39342EB24C6A3F7F133871811615E6D8F3E258F` |
| Backtest set | `3BD36963F7E1D5ABE218F53341BE3C8B382451666F2590376C55E9C48829773D` |
| Reference test | `A4472650F2BCDA43D3C83F598FAC501FC42418646569FBEB78F5AE36F82A68A0` |

## Q02 Capacity And Enqueue Evidence

The non-mutating target sweep at `2026-08-11T11:21:29+00:00` selected exactly
one priority-track never-tested row for `QM5_20279 / XTIUSD.DWX`, no stranded
rows, and no deferred rows. It observed 1,130 pending items against the 7,000
queue ceiling and made no change.

Immediately before apply mode, the path-anchored MT5 sample at
`2026-08-11T11:22:12+00:00` found two executing factory terminals, T4 and T7,
against the CPU ceiling of seven. The machine-wide terminal count was four
because `C:/QM/mt5/T_Live` and an FTMO terminal were separately observed;
neither belongs to T1-T10 capacity and neither was accessed or changed. The
target-only work-item readback was zero before mutation.

The bounded apply at `2026-08-11T11:22:16+00:00` enqueued exactly one never-
tested priority-track row. Sweep evidence is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`; its internal
`generated_at` is `2026-08-11T11:22:16+00:00`, `apply=true`, and its selected
setfile is
`QM5_20279_wti-expw-mom_XTIUSD.DWX_D1_backtest.set`.

Immediate `farmctl work-items --ea QM5_20279` readback returned:

| Field | Value |
|---|---|
| Work item | `32cbb0ce-42eb-498a-b8da-2a0115c78494` |
| Phase | `Q02` |
| Kind | `backtest` |
| Symbol | `XTIUSD.DWX` |
| Status | `pending` |
| Attempt | 0 |
| Claimed by | none |
| Verdict | none |

This is an enqueue handoff, not a Q02 screening verdict.

## Commits Before This Closing Evidence

- `11467a224` — OWNER mission authorization and exact G0 decision.
- `abda5b96e` — bounded source packet plus approved/intake cards.
- `88a87945a` — deterministic EA-ID reservation.
- `413ca52d2` — target SPEC scaffold.
- `ebb9bbd55` — slot-0 WTI magic allocation and resolver generation.
- `cac521f0f` — EA source, EX5, reference test, fixed-risk setfile, and Q01
  evidence bindings.
- `ab24d4521` — Q02 work-item binding in canonical/build cards and SPEC.

## Safety Boundary

- No dispatch tick, manual backtest, smoke test, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled; `T_Live` was not accessed or changed.
- The portfolio gate and T_Live manifest were not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from Q01 or the Q02 enqueue.
