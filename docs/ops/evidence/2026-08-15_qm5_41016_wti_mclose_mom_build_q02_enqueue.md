# QM5_41016 WTI Month-Closing Momentum - Build And Q02 Enqueue Evidence

Date: 2026-08-15

Branch: `agents/board-advisor`

## Outcome

One new structural, low-frequency commodity sleeve was researched, approved,
allocated, built, validated, committed, and enqueued once for Q02:

- EA: `QM5_41016_wti-mclose-mom`
- Strategy ID: `MOP-WTI-MCLOSE-MOM-2026_S01`
- symbol / timeframe: `XTIUSD.DWX` / D1
- magic slot / magic: `0` / `410160000`
- cadence: at most one consumed attempt per broker month
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`
- Q01: `PASS`
- Q02: `ENQUEUED; pending` at verification

This is a new outright WTI structural carrier, distinct from the existing
XAU, SP500, NDX, and XNG sleeves. It is not a claim of profitability,
certification, portfolio admission, or realized decorrelation. Those claims
require the downstream governed phases, including portfolio correlation at
Q09.

## Source And Translation Boundary

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-MCLOSE-MOM-2026/source.md`. The OWNER mission
was durably recorded before card extraction in
`decisions/2026-08-15_wti_mclose_momentum_source_approval.md`.

The packet traces to Moskowitz, Ooi, and Pedersen (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The complete governed review is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; its reviewed PDF has SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

The paper supports only the own-return-sign continuation family and explicit
WTI membership in its commodity-futures universe. It does not test this
WTI-only final-five-to-first-five session translation, Darwinex CFD, fixed
hard stop, costs, or the QM portfolio. All of those are disclosed QM choices
to be falsified by Q02 and later gates.

The G0 decision is
`decisions/2026-08-15_wti_mclose_momentum_g0.md`. The canonical, approved, and
build copies of the Strategy Card are byte-identical.

## Non-Duplicate Evidence

The deterministic pre-allocation checker scanned 4,503 EA-registry rows and
599 root cards. It found no exact identity and one expected fuzzy sibling,
`wti-mopen-mom`, at score `0.64`. Manual review separated the material clocks:

- `QM5_41013_wti-mopen-mom` forms on the first five current-month sessions,
  enters on the sixth, and holds the residual month.
- `QM5_41016_wti-mclose-mom` forms on the final five prior-month intervals,
  enters on the first current-month bar, and exits on the sixth.
- `QM5_12983_wti-tom-mom` uses a 63-D1 magnitude and a multi-day turn window.
- `QM5_13049_xti-1w-mom-vol` is rolling weekly and adds magnitude and
  realized-volatility gates.
- `QM5_20187_wti-tsmom1m` owns a complete prior-month formation and complete
  next-month hold.

Verdict:
`CLEAN_WTI_FINAL_FIVE_TO_FIRST_FIVE_SEGMENT_MOMENTUM_AFTER_MANUAL_REVIEW`.

## Locked Build

The EA mechanizes exactly one monthly state transition:

1. On a new D1 bar, reconstruct the broker month and count completed bars in
   the current month.
2. Accept only the first current-month bar within five minutes of its open;
   a later restart consumes the month flat.
3. Persist the `yyyymm` attempt before history, signal, news, spread, quote,
   sizing, or order gates.
4. Require all six immediately preceding D1 closes to be finite, positive,
   strictly ordered, and inside the immediately prior broker month.
5. Follow the sign of `log(Close[1] / Close[6])`; exact zero remains flat.
6. Size from one frozen `3.5 * ATR(20,D1)` hard stop, with no target and no
   signal-magnitude risk scaling.
7. Close on the first tick of the sixth entry-month D1 bar, with month-change,
   twelve-calendar-day, and malformed-position repair paths.

There is exactly one `backtest` setfile. Both news axes and Friday close are
locked OFF. The implementation has no ML, trained output, banned signal
indicator, external runtime feed, optimizer surface, pending order, grid,
martingale, pyramid, scale-in, or partial exit.

## Q01 Validation

- build prerequisite guard: `PASS`;
- strict compile: `PASS`, 0 errors, 0 warnings;
- final compile log:
  `C:/QM/repo/framework/build/compile/20260815_202229/QM5_41016_wti-mclose-mom.compile.log`;
- strict build check: `PASS`, 0 failures, 0 warnings;
- build report:
  `D:/QM/reports/framework/21/build_check_20260815_202228.json`;
- targeted MQ5/setfile guardrails: `PASS`, two files checked, zero findings;
- Strategy Card schema lint: `PASS` for canonical, approved, and build copies;
- G0 card lint: `PASS`;
- SPEC validation: `PASS`;
- deterministic reference suite: eight tests, all `PASS`;
- P1 artifact validation: `PASS` at
  `D:/QM/reports/pipeline/QM5_41016/P1/P1_QM5_41016_result.json`;
- EX5 size: 382,668 bytes.

The repository-wide registry validator emitted its pre-existing global
backlog. No unrelated registry cleanup was attempted. The targeted EA/magic
rows, generated resolver, build prerequisite guard, card lints, strict build,
and P1 artifact validation accepted EA 41016.

## Commit Chain Before Enqueue Seal

| Commit | Purpose |
|---|---|
| `3aa02c4f1` | record source approval and governed translation packet |
| `e5734252b` | approve G0 card and deterministically allocate EA 41016 |
| `fe12106fc` | register magic 410160000 and regenerate the resolver |
| `f2b49d3ad` | implement, compile, test, and seal the Q01 build |

## Artifact SHA-256 Values At Enqueue

| Artifact | SHA-256 |
|---|---|
| Bounded source packet | `AF4C7CB478069AD00F18E8251A870DCF44D1463C6E9D6D0D2DE5EA1F934A7ED8` |
| Complete parent source review | `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042` |
| Source approval | `FBC58D5FB664BFFCFFFFFD41A2DB2EC74BBECA7261A7A11E1100C2B9ECAA7FA8` |
| G0 decision | `1F0BDA7B8614E38096078C67F3E139E0C8CAD2490FF66791297C69977501DEE6` |
| Canonical / approved / build card | `89C5FC0271A07009DA43A7F801027E3844CDDD718EEC078269F8654DD342955B` |
| MQ5 | `E26603C18FB876CB9196D9427B7460AE6A6CB3ED8C0AFAA53ADBFA23581841C9` |
| EX5 | `420370E460739F14D47FC722DA995C0B7F4E9C07EFFFA93DB998BFA25C41E27E` |
| SPEC | `6631593EB32B4F1DF81C704F5716AC1BD13EC2B7EF36DB65EB44CDAE1C062D2D` |
| Reference suite | `1D62177C716E559FA8D5E3DA6898A2469D2D9D702FBCF7BEE5513215E1CA29BB` |
| Backtest set | `9DDA96E3555F6764632C5BD57BD5D51A28E1CAD071E8E2EBD4BD5A1DDC30139C` |
| Generated magic resolver | `CB1C0B987D0BDAC53EAF072A06FB1AB528A6FDC5645C1D5882E73F8688C451A5` |

## Q02 Capacity And Enqueue Evidence

The exact target-only no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41016 --symbols XTIUSD.DWX --max-part2-per-run 0

It reported `APPLY=False`, one selected never-tested item, zero skips, zero
stranded retries, zero deferred promotions, and one priority-track item.

A path-anchored read-only process sample at
`2026-08-15T20:25:10.6405019Z` found one governed factory terminal: T3, PID
17816. Only exact executables matching `D:/QM/mt5/T1` through `T10` were
counted; `T_Live` cannot match. The binding ceiling is seven terminals.

The immediately pre-apply sample at `2026-08-15T20:25:31.7458105Z` again
found only T3, so the CPU ceiling was not binding. The exact apply command was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_41016 --symbols XTIUSD.DWX --max-part2-per-run 0

It inserted exactly one never-tested priority-track item, with no retry,
deferred promotion, or skip. Direct read-only database verification returned:

| Field | Value |
|---|---|
| Work item | `52032468-6d7e-46ac-a46a-310185ddf5cd` |
| Phase / kind | `Q02` / `backtest` |
| Symbol / timeframe | `XTIUSD.DWX` / D1 |
| Status at verification | `pending` |
| Attempt count | `0` |
| Claimed by | none |
| Created UTC | `2026-08-15T20:25:31+00:00` |
| Priority track | `true` |

The pending queue moved from 1,018 to 1,019 rows against the helper's 7,000
row ceiling. A post-enqueue sample at `2026-08-15T20:26:08.8242405Z` still
found only T3 with the same PID. `D:/QM/strategy_farm/state/FACTORY_OFF.flag`
was absent. The helper's shared receipt is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`; because that file
is shared and mutable, this evidence relies on the scoped command receipts
and unique database row.

## Safety Boundary

- No manual backtest, phase runner, dispatch tick, terminal reservation,
  tester launch, process mutation, or factory-lock bypass was performed.
- No live, demo, shadow, stress, or optimization setfile was created.
- No terminal was started, stopped, reserved, reaped, or altered.
- AutoTrading was not toggled.
- Neither the portfolio gate nor the T_Live manifest was touched.
- Q02 enqueue is not a Q02 verdict, certification, profitability evidence,
  realized decorrelation evidence, portfolio admission, or live-use
  authorization.
