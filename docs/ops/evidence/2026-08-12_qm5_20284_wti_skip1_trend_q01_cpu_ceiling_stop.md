# QM5_20284 WTI Skip-One-Month Trend — Q01 PASS / Q02 CPU-Ceiling Stop

Date: 2026-08-12 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20284_wti-skip1-trend` is a new low-frequency outright WTI structural-
trend candidate. Its governed card, deterministic allocation, V5 EA, strict
binary, and one `RISK_FIXED` backtest set are complete. Current target-only
Q01 validation is `PASS`.

Q02 was **not enqueued**. A target-only dry run selected exactly one
priority-track `XTIUSD.DWX` row, but the binding pre-apply sample then found
seven path-anchored T1-T10 tester processes against the hard ceiling of seven.
The OWNER-approved card says to stop before enqueue at that ceiling. Immediate
readback remained zero work items for `QM5_20284`. No dispatch tick or manual
backtest was run.

## Edge And Non-Duplicate Boundary

At the first processed D1 bar after a genuine broker-month transition, the EA
reconstructs fourteen consecutive completed WTI month-end closes. It validates
the newest completed monthly return but excludes it from the decision, then
trades the sign of the exact twelve-month log return ending one full month
before entry. Exact-zero or invalid state consumes the month flat. Every entry
receives a frozen `3.5 * ATR(20,D1)` hard stop, no take-profit, monthly renewal,
and a forty-day stale exit.

The canonical pre-allocation review found no exact identity. The load-bearing
difference from `QM5_12603` is the excluded newest month; from `QM5_20239`, the
absence of an opposing-newest-month pullback gate; from `QM5_20258`, the absence
of a nested-horizon vote; and from `QM5_20280`, the delayed twelve-month rather
than current four-month interval. Verdict:
`CLEAN_AFTER_FUZZY_AND_MECHANIC_REVIEW`.

WTI is a crude-oil carrier absent from the current XAU, SP500, NDX, and XNG
book. Carrier novelty does not prove realized low correlation; unchanged Q09
owns that conclusion if the candidate survives Q02-Q08.

## Source And Governance

The bounded packet is
`strategy-seeds/sources/MOP-WTI-SKIP1-2026/source.md`. Its complete-read parent
is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The governed 23-page paper receipt records PDF
SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`
and explicitly includes NYMEX WTI crude in the commodity-futures universe.

The paper supports the broad monthly own-price continuation family and WTI
carrier. It does not prescribe skipping the newest completed month, the
Darwinex continuous-CFD port, broker-month reconstruction, fixed-dollar risk,
ATR stop, spread cap, attempt ledger, or lifecycle. Those are transparent
pre-result QM hypotheses. Durable G0 authorization is
`decisions/2026-08-11_qm5_20284_wti_skip1_trend_g0.md`.

Card schema/ML lint, G0 lint, canonical/intake/build-card identity, SPEC
validation, and the exact EA-ID/magic tuple all passed. The target allocation
is `QM5_20284` / `wti-skip1-trend` / `XTIUSD.DWX` / slot 0 / magic
`202840000`.

## Q01 Evidence

- Target build check: `D:/QM/reports/framework/21/build_check_20260811_223840.json`,
  PASS with zero failures and zero warnings.
- Final strict compile: `D:/QM/reports/compile/20260811_223924/summary.csv`,
  PASS with zero errors and zero warnings.
- Final compile log:
  `C:/QM/repo/framework/build/compile/20260811_223924/QM5_20284_wti-skip1-trend.compile.log`.
- P1 artifact validation:
  `D:/QM/reports/pipeline/QM5_20284/P1/P1_QM5_20284_result.json`, PASS.
- Independent endpoint/orientation test:
  `framework/EAs/QM5_20284_wti-skip1-trend/docs/test_skip1_reference.py`, PASS.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Manual smoke/backtest: none, as explicitly excluded by the card.

Evidence SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| Bounded source packet | `BF267237B5939A86ACF73246BAB20FB1F66804D28EEA4EE842BBB541B0346AB4` |
| Canonical/intake/build card | `7BB1406B156E5EDED8D5D3BF4C10CFBCDD1EA76E95E7BC3789ECE16622EDCA0C` |
| MQ5 | `1B3D943B85A0AD036CCA5B6AF989E4317C953A105592D0823634D8BF5E6565DC` |
| EX5 | `D03C24C8B07973C981BFDA722C8342E4A0F9638401AC4EF4B2020729C862FA8E` |
| Backtest set | `99ADD8661DB4335AAD06C36576D8C116A9F8368E1444AA78512C77E604FBB84A` |
| Reference test | `70FAF632EA6487972FEE8E5F2BF63AA5C08E89C67FD1EC57994CE06EAF8D64F8` |
| Final compile summary | `DA7B5E960159DAA1BD03428E392AA49A43A1165D41DF2CC3A4757055EB6EAA2F` |
| Target build-check report | `6AAFEE719E71BFF3C49623FD4082D1BDB2518B32AFF7BF81A263680FFE82BD5C` |
| P1 result | `E117430720B390555DBD35AD41B34D93170674194DF3B7C7B36C664F4D0AC1A1` |

The three card copies are byte-identical after this status update. The
repository-wide registry validator still reports unrelated historical
inventory debt; the target-only strict build gate and explicit one-row checks
for `QM5_20284` pass. This mission did not edit that debt.

## Q02 Dry Run And CPU-Ceiling Evidence

The target-only dry run used `--ea QM5_20284`, `--symbols XTIUSD.DWX`, and
`--queue-ceiling 7000`. At `2026-08-11T22:40:53+00:00` it observed 1,103
pending items, a wave budget of 5,897, selected exactly one never-tested
priority-track row, and selected no stranded or deferred rows. Its evidence is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, `apply=false`,
SHA-256
`586AF040A4B985FB4B84963FC42A487E4FB4DF6450B8FCF3CF875BAB46B199A1`.

The binding path-anchored process sample at
`2026-08-11T22:42:22.8387848Z` counted only exact executables under
`D:/QM/mt5/T1..T10/terminal64.exe` and explicitly excluded `T_Live`:

| Terminal | PID |
|---|---:|
| T2 | 2508 |
| T5 | 20796 |
| T6 | 5636 |
| T7 | 10256 |
| T8 | 1108 |
| T9 | 13464 |
| T10 | 12772 |

That is 7/7, so the apply was not invoked. Immediate
`farmctl work-items --ea QM5_20284` readback returned `count=0`.

## Safety Boundary

- No Q02 database row was created and no dispatch tick was invoked.
- No manual backtest, smoke test, terminal launch, process stop, reservation,
  or worker mutation was performed.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled; `T_Live` was not accessed or changed.
- The portfolio gate and T_Live manifest were not touched.
- No efficacy, certification, decorrelation, or portfolio-admission claim is
  inferred from Q01.

The next authorized action is a target-only Q02 apply only after a fresh
path-anchored sample is below the seven-process ceiling.
