# QM5_20285 WTI Fixed-Step Huber Trend — Q01 PASS / Q02 Enqueued

Date: 2026-08-12 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20285_wti-huber-mom` is a new low-frequency outright-WTI structural
trend candidate. It is built, Q01 is `PASS`, and exactly one current-binary
`XTIUSD.DWX` row was enqueued to Q02 below the path-anchored factory CPU
ceiling. Work item `3e3d87c9-3d4e-4188-8ae6-4840a5259a11` was active at
immediate readback, attempt 0, claimed by T6, with no verdict. The resident
fleet claimed the row; this mission issued no dispatch tick and ran no manual
backtest.

## Edge And Non-Duplicate Boundary

At the first processed D1 bar after each genuine broker-month transition, the
EA reconstructs thirteen consecutive completed WTI month-end closes and forms
twelve adjacent chronological log returns. It computes the even median and
even raw MAD, freezes `delta = 1.5 * 1.4826 * MAD`, initializes the location at
the median, and runs exactly 32 Huber reweighted-mean updates. It buys a
positive final location and sells a negative one. Exact zero or invalid state
consumes the month flat. Every entry receives a frozen
`3.5 * ATR(20,D1)` hard stop, no take-profit, monthly renewal, and a forty-day
stale exit.

The canonical pre-allocation checker scanned 4,350 EA-registry rows and 461
root cards. It found no exact identity and returned one expected shared-source
fuzzy neighbor, `QM5_20277_wti-winsor-mom`. Manual review separated the new
re-centering statistic from that one-pass fixed-tail replacement and from
`QM5_20282_wti-madcap-mom`, which performs one fixed median-centered cap then
an equal-weight mean. Raw-median, trim, quartile-trimean, pseudomedian,
cumulative, vote/run, weighting, regression, rank, path-efficiency, and
skip-month variants use different functionals or endpoint objects. The two
even-sample sorts, constants, frozen scale, residual weights, 32 updates,
exact-zero rejection, and consumed monthly attempt are jointly load-bearing.
Verdict: `CLEAN_AFTER_WINSOR_AND_MADCAP_MECHANIC_REVIEW`.

Independent reference vectors cover positive, negative, and symmetric-zero
states; zero-MAD fail-closed behavior; close-to-return orientation and
cross-year month continuity; and a locked vector where this Huber location is
negative while both the Winsor and MAD-cap neighboring estimates are
positive.

WTI is a crude-oil carrier absent from the current XAU, SP500, NDX, and XNG
book. Carrier and statistic novelty do not establish realized decorrelation;
unchanged downstream gates, including Q09, own that conclusion if the
candidate survives Q02-Q08.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-HUBER-2026/source.md`. Its complete-read parent
is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The governed 23-page paper receipt records PDF
SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`
and explicitly includes NYMEX WTI crude in its commodity-futures universe.
Huber (1964), *Robust Estimation of a Location Parameter*, DOI
`10.1214/aoms/1177703732`, supplies bounded-influence statistical lineage
only; no complete-read claim is made for that paper.

Neither source tests the exact locked estimator, Darwinex continuous CFD,
broker-month reconstruction, fixed-dollar sizing, ATR stop, spread cap,
attempt ledger, or lifecycle. These are transparent pre-result QM
mechanizations. No source performance, WTI-specific alpha, CFD equivalence,
or portfolio-correlation result is imported. Durable G0 authorization is
`decisions/2026-08-12_qm5_20285_wti_huber_mom_g0.md`.

R1-R4 pass: a named peer-reviewed trading source with DOI, complete governed
read, durable hash, and explicit WTI membership; separately bounded
statistical lineage; exact mechanical rules; a registered WTI D1 route; and
deterministic native arithmetic without ML, trained output, banned signal
indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20285` / `wti-huber-mom` /
  `MOP-TSMOM-2012_XTI_HUBER12_S33`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202850000`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- The EA-ID and target magic rows each occur once. Resolver generation at
  allocation kept 15,890 rows and dropped zero. Current resolver SHA-256 at
  closing evidence is
  `03E31EB94009A3A76E06094AB34CA64C86022789A7B29366121C96993B368F09`.
- Final strict compile: `D:/QM/reports/compile/20260812_000246/summary.csv`,
  PASS with zero errors and zero warnings.
- Final strict compile log:
  `C:/QM/repo/framework/build/compile/20260812_000246/QM5_20285_wti-huber-mom.compile.log`.
- Targeted build check:
  `D:/QM/reports/framework/21/build_check_20260812_000245.json`, PASS with
  zero failures and zero warnings.
- P1 artifact validation:
  `D:/QM/reports/pipeline/QM5_20285/P1/P1_QM5_20285_result.json`, PASS.
- Independent statistic/clock test:
  `framework/EAs/QM5_20285_wti-huber-mom/docs/test_huber_reference.py`, PASS.
- Card schema/ML lint, G0 lint, build-prerequisite guard, SPEC validation, and
  canonical/intake/build-card identity: PASS.
- Setfile header build hash:
  `7dd6384e2121627f6ed19af046b06b79b922ecb17012d94e60a4086595f047e3`.
- Manual smoke/backtest: none.

Final repository artifact SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| G0 decision | `011D7A16CF8BAE61D72C2428820E62E41B308BAB8730F5F3E115094C5B77740A` |
| Bounded source packet | `849EEF9C014DFFC16F42531E38F995767F7C516BEF0824559E7D3A057E59F611` |
| Canonical/intake/build card | `6904FFC4864BB9BF5EC5388E9E66D0C0DBAEEFA656D2CD1E0E225024CB85E531` |
| MQ5 | `C2DE291A58FE754AFEA630CE7AD1EE259F537556F935AB7E60672B384DAEC95C` |
| EX5 | `3004394F069A703C82CA2CF68AEE788FE48C9CADA29043DED96D56AAD4D99E3A` |
| SPEC | `7B4CCFFBC9954AFFB6690C7EEAC8FF3A4B7003BFC37CD73FCD42248BB0A10737` |
| Backtest set | `4B9FD7AEFE619B5C248A3C01D6AF7983A32A6654C2771ABB6828A243D0BA2628` |
| Reference test | `A7AED7D31BD68BE284456827F08263BD117495002262C7DFC2518132B9916559` |

## Q02 Capacity And Enqueue Evidence

The initial path-anchored sample at `2026-08-12T00:07:44.7315078Z` found two
exact factory terminals, T8 and T10, against the binding ceiling of seven.
The paired pre-enqueue `farmctl work-items --ea QM5_20285` readback returned
`count=0`.

The target-only dry run at `2026-08-12T00:07:52+00:00` selected exactly one
never-tested priority-track row for `QM5_20285 / XTIUSD.DWX`, zero stranded
rows, and zero deferred rows. It observed 1,103 pending items against the
7,000 queue ceiling. The dry-run evidence SHA-256 was
`CE0EB322319B64B05E2E1F6A27380C91F4DFAC6A0A4402E16313DF778A812C28`.

The binding pre-apply sample at `2026-08-12T00:08:43.2153841Z` found three
exact factory terminals against the ceiling of seven:

| Terminal | PID |
|---|---:|
| T2 | 8724 |
| T8 | 12888 |
| T10 | 12772 |

Only exact executable paths under `D:/QM/mt5/T1..T10/terminal64.exe` counted,
with an explicit `T_Live` exclusion. With 3/7 active, the bounded apply at
`2026-08-12T00:08:49+00:00` enqueued exactly one never-tested priority-track
row. The captured apply evidence is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, `apply=true`, with
SHA-256
`87464516F382217A94D94FA2ECC6C8DE1CA644C5BAB19624790F8EF76B1728BA`.

Immediate `farmctl work-items --ea QM5_20285` readback returned:

| Field | Value |
|---|---|
| Work item | `3e3d87c9-3d4e-4188-8ae6-4840a5259a11` |
| Phase | Q02 |
| Kind | backtest |
| Symbol | `XTIUSD.DWX` |
| Status | active |
| Attempt | 0 |
| Claimed by | T6 |
| Verdict | none |

The item was created at `2026-08-12T00:08:49+00:00` and updated at
`2026-08-12T00:08:58+00:00`. The post-apply path sample at
`2026-08-12T00:09:06.5852468Z` remained 3/7. T6 claimed the item through the
already-running paced fleet; this mission did not invoke a dispatch tick or
launch a terminal. Q02 is enqueued/active, not screened or passed.

## Commits Before This Closing Evidence

- `79d775b50` — OWNER mission authorization and exact G0 decision.
- `e95490b6e` — bounded source packet plus approved/intake cards.
- `6224d7967` — deterministic EA-ID reservation.
- `3582cf2b2` — target SPEC scaffold.
- `29016b885` — slot-0 WTI magic allocation and resolver generation.
- `7ef4189fa` — EA source, EX5, reference test, fixed-risk setfile, and Q01
  evidence bindings.

Commits were scoped with explicit pathspecs on `agents/board-advisor`; unrelated
pre-existing and concurrent worktree changes were preserved.

## Safety Boundary

- No dispatch tick, manual backtest, smoke test, or downstream phase was run
  by this mission.
- No terminal was started, stopped, reserved, reaped, or altered by this
  mission.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled; `T_Live` was not accessed or changed.
- The portfolio gate and T_Live manifest were not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from Q01 or the Q02 enqueue.
