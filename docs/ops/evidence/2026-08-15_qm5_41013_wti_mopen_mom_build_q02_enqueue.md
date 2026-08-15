# QM5_41013 WTI Month-Opening Momentum Build And Q02 Enqueue

Date: 2026-08-15 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: Q01 PASS; exactly one XTIUSD.DWX D1 Q02 item enqueued and pending

## Outcome

`QM5_41013_wti-mopen-mom` is a new structural, low-frequency WTI candidate.
At the sixth tradable WTI D1 bar of each broker month, it follows the sign of
the return from the prior broker-month closing bar to the fifth current-month
closing bar. It holds the resulting single outright WTI position until the
next broker month, subject to a frozen `3.5 * ATR(20,D1)` hard stop and a
35-calendar-day stale-position exit.

The signal is a fixed calendar/price-return rule: no trained output, banned
signal indicator, external runtime feed, grid, martingale, scale-in, or
pyramid is present. The only setfile is an `XTIUSD.DWX` D1 backtest set with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No live, demo,
shadow, stress, or optimization setfile was created.

WTI supplies direct crude-oil exposure distinct from the current XAU, SP500,
NDX, and XNG carriers. That carrier and mechanic novelty is not evidence of
low realized portfolio correlation; the unchanged downstream correlation
gate owns that falsification if the candidate survives Q02-Q08.

## Source And Non-Duplicate Boundary

The governed packet is
`strategy-seeds/sources/MOP-WTI-MOPEN-MOM-2026/source.md`. Its reputable-source
lineage is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The complete 23-page parent-paper receipt in
`strategy-seeds/sources/MOP-TSMOM-2012/source.md` records PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

The paper supports testing monthly own-return continuation and includes WTI
in its commodity universe. It does not test the exact first-five-session
formation, sixth-bar decision clock, residual-month CFD hold, fixed-dollar
risk, ATR stop, spread ceiling, trade density, profitability, or QM book.
Those are disclosed QM translations, not transferred source claims.

The canonical pre-card duplicate scan returned CLEAN across 4,500 EA-registry
rows and 596 root cards. Manual review separated this exact mechanic from
first-five-session range breakouts, rolling five-day momentum/volatility
filters, prior-full-month momentum, third-session rules, and the incumbent
short-horizon XNG RSI pullback. The fixed sixth-bar clock, prior-month-close
anchor, pure five-session endpoint sign, and next-month lifecycle were not
already built.

## Allocation And Commit Chain

- Source approval and governed packet: `97289ee9f`.
- G0 decision, synchronized approved cards, and deterministic EA-ID
  allocation: `886b1f97d`.
- Active slot-0 magic, generated resolver, EA source/binary, SPEC, reference
  tests, fixed-risk setfile, and Q01 state: `883709b09`.

The registries bind `QM5_41013`, slug `wti-mopen-mom`, and strategy ID
`MOP-WTI-MOPEN-MOM-2026_S01` to active magic `410130000` on `XTIUSD.DWX`.
Resolver generation kept 15,966 rows, dropped zero, and embedded registry
SHA-256 `FB104114D16D98A546F973B4ADB79944117D9B5E8BB565895414AFA226430AD2`.

## Q01 Evidence

- Reputable-source approval, G0 lint, and Card-v2 schema/ML lint: PASS.
- Canonical, approved, and build-time card copies: byte-identical.
- Approved-card build prerequisite guard: PASS for EA ID, magic, and EA
  directory.
- Mandatory seven-section SPEC validation: PASS.
- Independent reference suite: 7 tests PASS. Coverage includes positive,
  negative, and exact-zero endpoint signs; four-bar waiting; six-bar late
  restart consumption; nonconsecutive-month rejection; and month/stale/
  malformed lifecycle exits.
- Strict MetaEditor compile: PASS with zero errors and zero warnings.
- Targeted strict V5 build check: PASS with zero failures and zero warnings.
- P1 artifact validation: PASS; EA directory and compiled `.ex5` present.
- Compiled binary size: 382,410 bytes.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260815_174304/QM5_41013_wti-mopen-mom.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260815_174304/summary.csv`.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260815_174629.json`.
- P1 result:
  `D:/QM/reports/pipeline/QM5_41013/P1/P1_QM5_41013_result.json`.
- Manual smoke/backtest: none.

Artifact SHA-256 values at enqueue sealing:

| Artifact | SHA-256 |
|---|---|
| Source packet | `721DFC8C4369C2461DE4FF9CC054B08D5A777EB15045A4F1FC1BCD9B6791E1C8` |
| Source approval | `41B25E1109B70D8BCF846D8A9004DF8588923D7C6519DE40541E5EC384327628` |
| G0 decision | `55CA14976AE16A9FC3792B7B148E0413FE42DDA290D81FBD719992C6955ABAE7` |
| Canonical/approved/build card | `84298D719E8DDFF1E8C6A7F6203F9CD3FB0E3C87D6F8840840EECC31EF70E8B1` |
| MQ5 | `4763B97F964D6DE2067EBA4E2DC73FBA6745D00889DB492F15D2B61E973187C3` |
| EX5 | `F02BBBC65F63C3643CE80101A13E098FEF34BEC0FAB9EF7C1271FEB7F3FDFFDA` |
| SPEC | `4AFC167E7566759C98C1F24DAE094004DC0BF2A8B0B4529599AE6A0389EFAB65` |
| Reference suite | `06D5EB51654F887AB504A22CD5B6EDDD901F9800DE782647C0B0117E864694EB` |
| Backtest set | `818EA0BE0837E84AB559B690C09452413A675F6195B3FE309D2910ADA3E353B2` |
| Magic resolver | `004F396BD1BF5F4F3CFECB4BB256A56DB5B11FA56388649E74966E85567519F8` |

## Q02 Capacity And Enqueue Evidence

The exact target-only dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41013 --symbols XTIUSD.DWX --max-part2-per-run 0

It reported `APPLY=False`, one selected never-tested item, zero scoped skips,
zero stranded retries, zero deferred promotions, and one priority-track item.

The binding path-anchored capacity sample immediately before the successful
apply was taken at `2026-08-15T18:04:55.8535802Z`. Only T3 was executing from
the exact governed `D:/QM/mt5/T1..T10/terminal64.exe` paths: one factory
terminal, below the seven-terminal backtest CPU ceiling.

Contended no-op attempts first encountered the fleet mutation lock and then a
SQLite writer lock. Direct read-only target verification found zero inserted
rows before retry; neither lock was removed or bypassed. After the locks
cleared, the exact apply command was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_41013 --symbols XTIUSD.DWX --max-part2-per-run 0

It inserted exactly one never-tested item, with no retry or deferred item.
Direct read-only SQLite verification returned:

| Field | Value |
|---|---|
| Work item | `4fdb029b-85fc-4cfd-ac07-3e9caaa412ed` |
| Phase / kind | `Q02` / `backtest` |
| Symbol / timeframe | `XTIUSD.DWX` / `D1` |
| Setfile | canonical `QM5_41013_wti-mopen-mom_XTIUSD.DWX_D1_backtest.set` |
| Status at verification | `pending` |
| Attempt count | `0` |
| Claimed by | none |
| Created UTC | `2026-08-15T18:05:01+00:00` |
| Priority track | `true` |

The helper's shared sweep evidence was
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`. No dispatch
command, phase runner, smoke test, or manual MT5 tester run was issued.

## Safety Boundary

- No tester, terminal, worker, or process was started, stopped, reserved,
  reaped, or otherwise altered by this work.
- No `T_Live` file, process, or manifest was touched; AutoTrading was not
  toggled.
- The portfolio gate and T_Live manifest were not touched.
- Q02 enqueue is not a screening verdict, certification, profitability
  evidence, realized decorrelation evidence, portfolio admission, or live-use
  authorization.
