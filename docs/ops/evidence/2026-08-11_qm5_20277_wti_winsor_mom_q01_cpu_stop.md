# QM5_20277 WTI Winsorized Momentum — Q01 PASS / CPU-Ceiling Stop

Date: 2026-08-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20277_wti-winsor-mom` is a new low-frequency outright WTI structural-
trend candidate. It is built and Q01 is `PASS`. Q02 is
`NOT_ENQUEUED_CPU_CEILING`: the binding path-anchored capacity sample found
seven executing T1-T10 factory terminals against the paced ceiling of seven.
The immediate target readback returned zero work items. No Q02 dry-run,
apply-mode enqueue, dispatch, smoke test, or manual backtest was run.

## Edge And Non-Duplicate Boundary

At each genuine `XTIUSD.DWX` broker-month transition, the EA reconstructs
thirteen consecutive completed WTI month-end closes and forms twelve adjacent
chronological log returns. It sorts the returns, replaces sorted indexes 0 and
1 with index 2, replaces indexes 10 and 11 with index 9, and averages all
twelve capped terms. A positive Winsorized mean buys, a negative mean sells,
and exact-zero or invalid states consume the monthly event flat. The package
renews at the next month transition and is otherwise protected by a frozen
`3.5 * ATR(20,D1)` hard stop and a forty-day stale exit.

The deterministic pre-allocation check scanned 4,342 EA-registry rows and 453
cards and found no exact duplicate. It surfaced only the expected fuzzy
matches to `QM5_20270_wti-trimmean-mom` (0.60) and
`QM5_20269_wti-medret-mom` (0.56). Manual review separated the mechanics:

- `QM5_20270` deletes four tail observations and divides the middle-eight sum
  by eight;
- `QM5_20277` caps those four observations, retains twelve terms, and divides
  by twelve, giving sorted indexes 2 and 9 three weights each;
- `QM5_20269` uses only the two central observed returns;
- `QM5_20276_wti-hl-mom` takes the median of 78 inclusive pairwise return
  averages; and
- cumulative-return, vote/run, slope, regression/rank, and path-efficiency
  systems estimate different functionals.

The reference vectors include an ordered sample where the Winsorized mean is
`-0.0075` while the existing middle-eight trimmed mean is `+0.00625`, proving
that this is not an alias of the closest fuzzy match. The exact thirteen
endpoints, twelve adjacent returns, ascending sort, boundary indexes 2 and 9,
two replacements per tail, divisor twelve, direction, monthly attempt, and
renewal lifecycle are load-bearing.

WTI adds a crude-oil carrier distinct from the current XAU, SP500, NDX, and
XNG instruments. Different carrier and estimator do not prove low or negative
realized correlation; Q09 alone may establish portfolio correlation if the
candidate survives the earlier gates.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-WINSOR-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The peer-reviewed paper includes WTI in its
commodity-futures universe and supports testing monthly own-price trend.

The paper does not specify Winsorization, the two-observation tail count, CFD
mapping, ATR stop, spread cap, or lifecycle. Those are explicit QM
mechanization choices. No source performance, CFD equivalence, or portfolio
correlation result is imported. G0 authorization is
`decisions/2026-08-11_qm5_20277_wti_winsor_mom_g0.md`.

Reputable-source checks R1-R4 pass: one named peer-reviewed DOI record with a
complete governed read and durable hash; exact mechanical rules; a registered
WTI D1 route; and deterministic native arithmetic with no ML, trained output,
banned signal indicator, external runtime feed, grid, martingale, scale-in,
or pyramid.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20277` / `wti-winsor-mom` /
  `MOP-TSMOM-2012_XTI_WINS12_S25`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202770000`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Resolver generation: 15,851 rows kept, zero dropped; an independent array
  alignment check found the target tuple exactly once at the final index.
- Strict compile: `D:/QM/reports/compile/20260811_051914/summary.csv`, PASS
  with zero errors and zero warnings.
- Strict compile log:
  `C:/QM/repo/framework/build/compile/20260811_051914/QM5_20277_wti-winsor-mom.compile.log`.
- Targeted build check:
  `D:/QM/reports/framework/21/build_check_20260811_052000.json`, PASS with
  zero failures and zero warnings.
- P1 artifact validation:
  `D:/QM/reports/pipeline/QM5_20277/P1/P1_QM5_20277_result.json`, PASS.
- Independent statistic reference test:
  `framework/EAs/QM5_20277_wti-winsor-mom/docs/test_winsor_reference.py`, PASS
  for constant-positive, constant-negative, exact symmetric-zero, two-outlier-
  per-tail, and trimmed-mean sign-divergence vectors.
- Card schema/ML lint, G0 lint, build-prerequisite guard, SPEC validation, and
  canonical/build-card identity: PASS.
- Generated setfile header build hash:
  `a369d91afd07fea9f3ddca9bbf46dbd0d48c9931ed4b50b4e26dfc98fe5f27a2`.
- Manual smoke/backtest: none.

Artifact SHA-256 values at the capacity stop:

| Artifact | SHA-256 |
|---|---|
| Bounded source packet | `9995A84CC81057042EE480ED95BD9816FBA9FE2304DAC4A6FC89B4F19E194EEF` |
| Canonical/build card | `1BBCCD6A058E54294E2998DDAD6C8A56F040873F17B150BC068D2A90DEEA2C9D` |
| MQ5 | `6E5AF6AD0F01A9B26BF2CE4593C3C042AACE1676D9F18666D377C53314D883A7` |
| EX5 | `54F0713634C2BE4451928A450AEBA268C92E05AC67235805B5C7806CCA4DC295` |
| SPEC | `E4BA1A5F63634A5392CD1FB4970720420FEC0CA750F4F18EA0B02C780FD26CB2` |
| Backtest set | `7CF4C2DD688A45F7E377D4C6628A393BD893E3FA593F11BCF0866B801489FFC0` |

## Q02 Capacity Stop

`farmctl mt5-slots` sampled the governed processes at
`2026-08-11T05:21:13+00:00` and found seven exact factory terminals:

| Terminal | PID | Active phase |
|---|---:|---|
| T1 | 6808 | Q04 |
| T3 | 7192 | Q04 |
| T4 | 8328 | Q04 |
| T5 | 13224 | Q02 |
| T6 | 11644 | Q05 |
| T8 | 16856 | Q02 |
| T9 | 10212 | Q07 |

Only executables rooted under `D:/QM/mt5/T1..T10/terminal64.exe` count. The
separate `C:/QM/mt5/T_Live` and FTMO processes were observed but excluded and
were not accessed or changed. The governed sample is exactly 7/7 and is
therefore binding. The paired target-only
`farmctl work-items --ea QM5_20277` readback returned `count=0`.

No sweep command was issued after the ceiling was observed. The next paced
operator may take a fresh immediate capacity sample and, only below the
ceiling, run:

```powershell
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20277 --symbols XTIUSD.DWX --max-part2-per-run 0
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20277 --symbols XTIUSD.DWX --max-part2-per-run 0
python tools/strategy_farm/farmctl.py work-items --ea QM5_20277
```

This is a ready-but-capacity-blocked handoff, not a Q02 screening verdict.

## Commits Before This Closing Evidence

- `f4c917e93` — OWNER mission authorization and exact G0 decision.
- `fd3238c35` — bounded source packet plus approved/intake cards.
- `f099f64cf` — deterministic EA-ID reservation.
- `526d4fd9c` — magic allocation, resolver generation, and SPEC scaffold.
- `725c1b5f0` — EA source, EX5, reference test, fixed-risk setfile, and Q01
  status.

## Safety Boundary

- No Q02 dry-run/apply, dispatch tick, manual backtest, smoke test, or
  downstream phase was run after the binding sample.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled; `T_Live` was not changed.
- The portfolio gate and T_Live manifest were not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from Q01 or the capacity stop.
