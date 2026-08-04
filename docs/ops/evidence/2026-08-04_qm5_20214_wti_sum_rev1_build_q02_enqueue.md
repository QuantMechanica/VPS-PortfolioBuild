# QM5_20214 WTI Summer Reversal Build And Q02 Enqueue

Date: 2026-08-04 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

One new structural, low-frequency energy candidate was researched, approved,
allocated, built, strictly validated, committed, and handed to the paced Q02
fleet:

- EA: `QM5_20214_wti-sum-rev1`.
- Strategy: first June-October D1 bar, trade opposite the exact completed
  prior broker-month WTI return, then close/renew monthly.
- Carrier: `XTIUSD.DWX`, D1, magic `202140000`.
- Cadence: exactly five eligible decisions per full year before gate losses.
- Q01: PASS, zero compile errors/warnings and zero build-check failures.
- Q02: one pending priority-track work item,
  `7a5d5ea4-a472-48d0-8a79-35a0c564d9c3`.

This supplies direct crude-oil exposure absent from the current
XAU/SP500/NDX/XNG book. That distinct carrier and opposite-sign mechanism are
research hypotheses, not evidence of realized decorrelation; the unchanged
downstream portfolio gate remains authoritative.

## Source And Non-Duplicate Boundary

The governed composite packet
`strategy-seeds/sources/BURAKOV-YANG-WTI-SUMREV1-2026/source.md` records full
reads of Burakov, Freidin, and Solovyev (2018), *International Journal of
Energy Economics and Policy* 8(2), 121-126, and Yang, Goncu, and Pantelous
(2017), SSRN 3069253. The former supplies the fixed WTI summer regime; the
latter supplies academic fixed-horizon commodity-reversal lineage. Neither
source tests this conjunction or transfers a WTI-CFD performance,
transaction-cost, drawdown, correlation, or portfolio result.

The deterministic check scanned 4,270 registry rows and 388 cards, found no
exact duplicate, and flagged the expected fuzzy sibling
`QM5_20213_wti-summer-mom1` at 0.80. Manual resolution is load-bearing:
`QM5_20213` follows the completed prior month, while `QM5_20214` always takes
the opposite direction. The nearest unconditional summer, winter momentum,
six-month reversal, weekly reversal, seasonal-pullback, and RSI2 builds use
different direction states, horizons, calendars, or mechanics.

G0 authorization is
`decisions/2026-08-04_qm5_20214_wti_sum_rev1_g0.md`.

## Commits And Allocation

- Source, G0 decision, and card: `fc68ca1f2`.
- EA/magic registry allocation and resolver regeneration: `8763abbae`.
- EA, binary, SPEC, approved/build card references, and fixed-risk set:
  `e8ceba53e`.
- Registry row: `20214,wti-sum-rev1`.
- Magic row: slot 0, `XTIUSD.DWX`, `202140000`.
- Resolver verification: exactly one EA row, one magic row, and one generated
  resolver mapping; resolver tests: 4 passed.

## Q01 Evidence

- Strategy-card schema lint: PASS; no missing sections or forbidden-library
  hits.
- G0 card lint: PASS.
- Seven-section SPEC validation: PASS.
- Symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings.
- Compile summary: `D:/QM/reports/compile/20260804_184912/summary.csv`.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260804_184912/QM5_20214_wti-sum-rev1.compile.log`.
- Strict V5 build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260804_184912.json`.
- Canonical backtest set: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`; no live/demo/shadow set was created.

Artifact SHA-256 values at handoff:

| Artifact | SHA-256 |
|---|---|
| Source packet | `c879a3c2a69328f389468972a302c9789225e5a3b00da039bbde9a9ca93a934e` |
| MQ5 | `7bad617e5f78fcea750cac0cfb78767e99739ad5798d8451a957f0818367ab89` |
| EX5 | `d42874143ee38c97a3b556fa27d728892d3512e582ff18c132dbcb7fb9b8826c` |
| Backtest set | `510e33d3986979ab79b0621ad674e58c2950d54ed4be767c6e5c17fc2a21f15b` |

## Paced Q02 Handoff

The exact no-mutation dry run was:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20214 --symbols XTIUSD.DWX --max-part2-per-run 0
```

It selected one never-tested priority-track row and no stranded retry or
deferred promotion. The successful apply started with 1,661 pending rows
against the 7,000-row ceiling and inserted exactly one row:

- Work item: `7a5d5ea4-a472-48d0-8a79-35a0c564d9c3`.
- Created: `2026-08-04T18:58:06+00:00`.
- Phase/kind: Q02 / backtest.
- Symbol: `XTIUSD.DWX`.
- Initial confirmation: pending, attempt 0, unclaimed, no verdict.
- Setfile: `QM5_20214_wti-sum-rev1_XTIUSD.DWX_D1_backtest.set`.

The pre-enqueue process scan found three active factory terminals (`T1`, `T3`,
and `T5`), below the seven-terminal CPU ceiling. Initial apply attempts
observed the live global mutation lock and made no change. A read-only Windows
snapshot identified the normal T10 worker claim section; it released the lock
without intervention, after which the same exact guarded apply succeeded. No
lock was deleted and no process was stopped.

## Safety Boundary

- No manual backtest or downstream phase was launched; the paced fleet owns
  Q02 execution.
- The backtest CPU ceiling was not reached.
- No live/demo/shadow setfile or deploy artifact was created.
- AutoTrading was not toggled; no T_Live configuration or manifest was
  accessed or changed.
- The portfolio gate and T_Live manifest were not touched.
- Q02 enqueue is not certification, profitability evidence, decorrelation
  evidence, or portfolio admission.
