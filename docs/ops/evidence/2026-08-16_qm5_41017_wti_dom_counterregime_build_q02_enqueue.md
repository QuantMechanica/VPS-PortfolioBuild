# QM5_41017 WTI Counter-Regime Calendar - Build And Q02 Enqueue Evidence

Date: 2026-08-16 (Europe/Berlin; queue timestamps below are UTC)

Branch: `agents/board-advisor`

## Outcome

One new structural, low-frequency commodity sleeve was researched, approved,
allocated, built, validated, committed, and enqueued once for Q02:

- EA: `QM5_41017_wti-dom-ctrreg`
- strategy ID: `BOROWSKI-MOP-WTI-DOMCOUNTER-2026_S01`
- symbol / timeframe: `XTIUSD.DWX` / D1
- magic slot / magic: `0` / `410170000`
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`
- Q01: `PASS`
- Q02: `ENQUEUED; pending` at verification

This is a sparse physical-crude calendar/counter-regime stream outside the
certified XAU, SP500, NDX, and XNG carriers. Carrier and mechanic differences
do not establish realized decorrelation; that remains a downstream Q09 test.

## Locked Edge

The EA consumes only actual broker-calendar day 8 and day 26 D1 bars:

1. On exact day 8, BUY only when the completed 252-D1 log return is negative.
2. On exact day 26, SELL only when the completed 252-D1 log return is positive.
3. Compute the state from `Close[1] / Close[253]`; never read current-bar OHLC.
4. Never move a missing weekend or holiday date to a neighboring session.
5. Require the first observed tick within five minutes of D1 open and persist
   the exact `yyyymmdd` attempt before any fallible entry gate.
6. Attach one frozen `2.75 * ATR(20,D1)` hard stop, no target, and close on the
   first following D1 bar with a one-calendar-day stale repair.
7. Keep both news axes OFF and the framework Friday close enabled at broker
   hour 21.

There is exactly one setfile and its environment is `backtest`. No sweep,
fallback arm, date shift, live/demo/shadow/stress/optimization set, ML, trained
output, banned signal indicator, external runtime feed, grid, martingale,
pyramid, or scale-in was added.

## Source And Claim Boundary

The approved composite packet is
`strategy-seeds/sources/BOROWSKI-MOP-WTI-DOMCOUNTER-2026/source.md`. It traces
to:

- Borowski (2016), *Journal of Management and Financial Sciences* 26, 27-44,
  for the reported positive WTI day-8 and negative WTI day-26 cells; and
- Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
  104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, for completed own-return
  sign as a slow instrument state.

Neither paper tests this opposing-state conjunction, Darwinex CFD mapping,
exact broker dates, one-session hold, fixed cash risk, ATR stop, costs,
portfolio correlation, or the QM book. Borowski's multiple calendar tests and
sample age are explicit first-order risks. Source approval and G0 are recorded
in `decisions/2026-08-15_wti_dom_counterregime_source_approval.md` and
`decisions/2026-08-15_wti_dom_counterregime_g0.md`.

## Non-Duplicate Evidence

Before allocation, the canonical checker scanned 4,504 EA-registry rows and
600 root cards and returned `CLEAN`, with no exact or fuzzy match. Manual
review separated the material siblings:

- `QM5_20036_wti-dom8-long` is unconditional day-8 long and has no state or
  day-26 arm.
- `QM5_20027_wti-dom26-short` is unconditional day-26 short and has no state
  or day-8 arm.
- `QM5_20215_wti-dom-trend` buys day 1 in a positive state and sells day 26 in
  a negative state. Its shared day-26 signals are mutually exclusive with
  this EA's positive-state shorts.
- `QM5_12603_wti-tsmom12m` is a monthly symmetric trend strategy without the
  exact-date/one-session lifecycle.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback and does not
  use this clock or state.

Verdict:
`CLEAN_WTI_EXACT_DAY8_DAY26_COUNTER_REGIME_CALENDAR_AFTER_MANUAL_REVIEW`.

## Q01 Validation

- deterministic build prerequisite guard: `PASS`;
- strict compile: `PASS`, 0 errors, 0 warnings;
- final compile log:
  `C:/QM/repo/framework/build/compile/20260815_221224/QM5_41017_wti-dom-ctrreg.compile.log`;
- strict targeted build check: `PASS`, 0 failures, 0 warnings;
- build report:
  `D:/QM/reports/framework/21/build_check_20260815_221224.json`;
- Strategy Card schema/ML lint: `PASS`, no missing sections and no ML hits;
- G0 card lint: `PASS`;
- deterministic mechanic reference suite: eight tests, all `PASS`;
- EX5 size: 377,544 bytes;
- committed resolver: 15,972 active rows, 0 dropped, registry SHA-256
  `B4AAA956019470C18C7501D05B825C53883284CEFA0DDB5B2CA1CBBB37E465DB`.

The repository-wide registry validator has a pre-existing global backlog. No
unrelated registry cleanup was attempted. The target guard, strict build,
magic row, and generated resolver all accepted EA 41017. A concurrent
uncommitted `QM5_32003` registry/resolver change was kept out of commit
`aa7485fe3` and restored in the working tree immediately afterward.

## Commit Chain Before Enqueue Seal

| Commit | Purpose |
|---|---|
| `22b4896d1` | approve the governed source intake |
| `d5c05ee9b` | approve the card and deterministically allocate EA 41017 |
| `aa7485fe3` | register magic, build, compile, test, and seal Q01 |

## Artifact SHA-256 Values At Enqueue

| Artifact | SHA-256 |
|---|---|
| Composite source packet | `4A29BA392B031177333D0CE56BCB098050367D85CDA221247380CC735187A71E` |
| Borowski governed review | `EB0C64CA243297778A585850B1C486A593E91259CC5941CFD4652A173E7A0413` |
| Moskowitz-Ooi-Pedersen governed review | `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042` |
| Source approval | `7161A31654348B849A6F36DC50796623B611B30240AFBB1F7406B0D7481DD3E9` |
| G0 decision | `B6E01BF748166A796CB7632885275FE36CC9AFF935D6B667448AA320B29F5176` |
| Canonical / approved / build card | `8D9865381D5F82CF11B213725530BEE586E8EFF0583AFFAD5118589EC45339A9` |
| MQ5 | `2D0EE9BAF1D8871647B4A03A7EFD2EB5F32271152AAC96A4D747356349948DF5` |
| EX5 | `2DF104131CB5EFE2CA891CD16EE9E824835EF885BC110B28E33A42E3F746E6F2` |
| SPEC | `C532990606ECF17FC23369A7EEC1DF12EF76D87D08BAD39E5E1B96D78EAF7346` |
| Reference suite | `070CCC5C11143A3E76D5AEF066048486CE7CD18391CE861F43D4F5407268820A` |
| Backtest set | `A5B79DA170C3A1B8813B9EC4FB08B7B15AE6B8E3D2C6B3BC2876DF2C1128217E` |

The three card copies were byte-identical when these hashes were recorded.

## Q02 Capacity And Enqueue Evidence

The target-only no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41017 --symbols XTIUSD.DWX --max-part2-per-run 0

It reported `APPLY=False`, one selected never-tested item, zero skips, zero
stranded retries, zero deferred promotions, and one priority-track item.

Immediately before apply, the exact factory-terminal sample at
`2026-08-15T22:19:14+00:00` found T1 and T8: 2 of the governed ceiling of 7.
The CPU ceiling was therefore not binding. `T_Live` and an unrelated FTMO
terminal were visible to the diagnostic but were not factory slots and were
not touched.

The exact apply command was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_41017 --symbols XTIUSD.DWX --max-part2-per-run 0

It inserted exactly one never-tested priority-track item, with no retry,
deferred promotion, or skip. Read-only verification returned:

| Field | Value |
|---|---|
| Work item | `7eb89f24-8be4-49a0-8b94-5501e124f059` |
| Phase / kind | `Q02` / `backtest` |
| Symbol / timeframe | `XTIUSD.DWX` / D1 |
| Status at verification | `pending` |
| Attempt count | `0` |
| Claimed by | none |
| Created UTC | `2026-08-15T22:19:19+00:00` |

The post-enqueue sample at `2026-08-15T22:19:53+00:00` found T1, T4, and T8,
still below the 7-terminal ceiling. The helper's shared receipt is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`; because that file
is shared and mutable, the scoped command result and unique queue row are the
durable evidence here.

## Safety Boundary

- No manual backtest, pipeline phase runner, dispatch tick, terminal
  reservation, tester launch, process mutation, or factory-lock bypass was
  performed.
- No terminal was started, stopped, reserved, reaped, or altered.
- AutoTrading was not toggled.
- Neither the portfolio gate nor the `T_Live` manifest was touched.
- Q02 enqueue is not a Q02 verdict, certification, profitability result,
  realized-decorrelation result, portfolio admission, or live authorization.
