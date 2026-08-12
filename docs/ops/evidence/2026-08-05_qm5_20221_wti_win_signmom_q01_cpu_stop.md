# QM5_20221 WTI Winter Return-Sign Momentum Q01 And CPU Stop

Date: 2026-08-05 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

One new structural, low-frequency energy candidate was researched, approved,
allocated, built, and strictly validated:

- EA: `QM5_20221_wti-win-signmom`.
- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `202210000`.
- Mechanic: during November-May only, count the non-negative signs of the
  twelve completed monthly WTI returns; buy when the sign share is at least
  0.40 and sell otherwise.
- Lifecycle: close before monthly renewal, force flat June-October, one
  consumed attempt per active month, forty-day stale guard, and a frozen
  `3.5 * ATR(20,D1)` hard stop with no target.
- Maximum cadence: seven packages/year after warm-up; retire below five
  completed packages/year.
- Q01: PASS with zero compile errors/warnings and zero build-check
  failures/warnings.
- Backtest set: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

Q02 was not enqueued. The no-mutation dry run selected exactly one
never-tested priority-track row. The immediate guarded apply precheck then
observed eight running factory terminals against the binding seven-terminal
CPU ceiling and exited before apply mode was invoked. No Q02 row or tester run
was created by this session.

## Sources And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/BURAKOV-PAPAILIAS-WTI-WINSIGN-2026/source.md`.

- Burakov, Freidin, and Solovyev (2018), *International Journal of Energy
  Economics and Policy* 8(2), 121-126, supply the fixed November-May WTI
  seasonal partition.
- Papailias, Liu, and Thomakos (2021), *Journal of Banking & Finance* 124,
  106063, supply the twelve completed monthly return signs, fixed 0.40
  threshold, direction map, and one-month renewal.

Both parent texts have durable complete-read records. Neither tests this
interaction, a Darwinex continuous CFD, broker-month reconstruction, fixed
cash risk, an ATR stop, transaction costs, or portfolio correlation. No source
performance statistic is imported as a QM expectation.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,278 registry rows and 394
canonical cards. It found no exact identity and the expected fuzzy
sign-momentum relatives. Manual review fixes the boundary:

- `QM5_13150_wti-signmom` uses the same twelve-sign statistic year-round;
  this candidate is forced flat June-October.
- `QM5_13116_xng-signmom` uses natural gas and no WTI winter regime.
- `QM5_20209_wti-winter-mom1` uses only the immediately completed monthly
  return sign.
- `QM5_20218_wti-winter-rev1` reverses that one-month object.
- unconditional winter, 252-D1 winter trend, and `QM5_12567` two-day
  oscillator builds use different formation objects or clocks.

The twelve binary signs, fixed threshold, November-May gate, June-October
flat state, and monthly renewal are jointly load-bearing. Ablating the season
gate or replacing the statistic recreates an existing parent.

## Allocation And Commits

- Source packet, durable G0 decision, and canonical card:
  `481e174821ea172980ddae4435deeb06b9980b09`.
- Registry and magic allocation, regenerated resolver, EA source/binary,
  SPEC, approved/build card references, and fixed-risk set:
  `be8d728ba4a941c5b0bb99aa89282cf07c2dcd09`.
- Final Q02 CPU-stop status and this evidence: the commit containing this
  document.
- EA registry: `20221,wti-win-signmom`.
- Magic registry: `XTIUSD.DWX`, slot 0, magic `202210000`.
- Generated resolver: 15,492 rows kept, zero dropped, registry SHA prefix
  `E3473D27490526A9`.

## Q01 Evidence

- Canonical and approved card schema lints: PASS; no missing sections or
  prohibited-library hits.
- G0 card guard: PASS.
- EA build authorization guard: PASS for EA ID 20221 and its directory.
- Seven-section SPEC validator: PASS.
- Symbol-scope validator: `SINGLE_SYMBOL_OK`, zero violations.
- Magic-resolver regressions: five passed.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260805_074444/QM5_20221_wti-win-signmom.compile.log`.
- Compile summary:
  `D:/QM/reports/compile/20260805_074444/summary.csv`.
- Strict V5 build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260805_074444.json`.
- EX5 size: 372,608 bytes.

The repository-wide registry validator reports 1,412 pre-existing issues and
exits nonzero. A target-filtered read found zero issue containing EA 20221,
`wti-win-signmom`, or magic `202210000`; no unrelated registry debt was
modified.

Artifact SHA-256 values after the CPU-stop status update:

| Artifact | SHA-256 |
|---|---|
| Source packet | `4CA0C62CD55E8833BDAC3F5317B3D077158A0F18BAC9370F823D577D7DDBB471` |
| Canonical card | `57AA8AB92EDB828CB76A3C8E3E92ED42FE5F43D31B709A23402422A59FCB9408` |
| Approved card | `57AA8AB92EDB828CB76A3C8E3E92ED42FE5F43D31B709A23402422A59FCB9408` |
| MQ5 | `EA5A6727B7C06E3C601F1F639FE9A610FBA90B8F06FF7029896BAE353CAE3D8A` |
| EX5 | `C0F02C8A84B1879217C28FBD4E7C050E8A1CC56119D1FF06485822C58D34E4D3` |
| SPEC | `952EAE0B940271996DB29F1074C036F8BAC48666E429B690446C99BF39CBF941` |
| Backtest set | `7DDA3D9649F4DD13DEB3159F272AB28F31A94CCA35B6FD36FA78A59A04693A14` |

## Q02 Dry Run And Enforced Stop

The exact no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20221 --symbols XTIUSD.DWX --max-part2-per-run 0

At `2026-08-05T09:50:20+02:00`, it reported one never-tested selection,
zero skipped rows, zero stranded rows, and one priority-track item. Its
evidence file is `D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`;
the embedded `apply` value is false.

The first path-anchored process scan at `2026-08-05T07:49:57Z` found six
running factory terminals (`T1`, `T2`, `T3`, `T6`, `T8`, `T9`), below the
ceiling. The immediate pre-apply scan at 2026-08-05 09:50:41 Europe/Berlin
found eight (`T1`, `T2`, `T3`, `T4`, `T5`, `T6`, `T8`, `T9`). The guarded
command returned `CPU_CEILING_STOP` with exit code 3 before calling the
enqueue script in apply mode.

The next paced operator may repeat the exact dry run and enqueue only after a
fresh immediate capacity check is at or below seven running factory
terminals. This document records readiness and a blocked handoff, not a Q02
verdict.

## Safety Boundary

- No manual backtest or downstream phase was launched.
- No apply-mode Q02 enqueue occurred after the ceiling was observed.
- No live/demo/shadow setfile or deploy artifact was created.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
- No terminal was started, stopped, reserved, reaped, or altered.
- The capacity count used only path-anchored T1-T10 factory terminals; the
  observed T_Live and separate FTMO processes were excluded.
