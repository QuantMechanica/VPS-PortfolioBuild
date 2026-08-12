# QM5_20227 WTI Season / One-Month Momentum Build And CPU-Ceiling Stop

Date: 2026-08-05 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

One new structural, low-frequency direct-energy candidate was researched,
approved, allocated, built, and strictly validated:

- EA: `QM5_20227_wti-seas-mom1`.
- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `202270000`.
- Mechanic: BUY November-May only when the exact immediately completed
  broker-calendar-month WTI return is positive; SELL June-October only when
  that return is negative; consume the month and stay flat on disagreement.
- Lifecycle: close before the next broker-month decision, with a forty-day
  stale guard and no intramonth re-entry.
- Risk: frozen `3.5 * ATR(20,D1)` server-side hard stop, no target,
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
- Expected cadence: five to seven completed packages/year; Q02 must retire
  below five/year.

The Q02 dry run selected exactly one `never_tested` priority item and no
stranded/recovery item. Q02 was **not enqueued** because the binding backtest
CPU ceiling was already exceeded. No Q02 result, profitability, decorrelation,
certification, or portfolio-admission claim is made.

## Source And Non-Duplicate Boundary

The governed source packet is
`strategy-seeds/sources/BURAKOV-MOP-WTI-SEASMOM1-2026/source.md`.

- Burakov, Freidin, and Solovyev (2018), *International Journal of Energy
  Economics and Policy* 8(2), 121-126, supply positive November-May and
  negative June-October WTI physical-season directions.
- Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
  104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, supply the exact
  one-month own-return sign family and one-month hold.

Both parent texts have durable complete-read repository records. Neither
tests their agreement, a Darwinex continuous CFD, fixed cash risk, costs, or
portfolio correlation. No source performance statistic transfers.

The deterministic pre-allocation check found no exact identity and one
expected fuzzy match to `QM5_20226_wti-seas-dow` because both belong to the
physical-season agreement family. Manual review resolves it: `QM5_20226`
uses a weekday event and one-session hold, while `QM5_20227` uses the exact
immediately completed monthly return and a month-to-month hold.

Other nearest builds are mechanically distinct: unconditional seasonal EAs
have no price agreement gate; year-round one-month momentum has no physical-
season direction; winter/summer one-month momentum may trade against the
season and cover disjoint windows; `QM5_20222` uses twelve-return sign breadth;
and `QM5_12567` is a short-horizon cumulative-RSI pullback.

## Allocation And Commits

- Approved source packet and durable G0 decision: `13b012c91`.
- Atomic EA-ID allocation and approved canonical card: `3096550e1`.
- Magic slot allocation and regenerated resolver: `cd985ea03`.
- EA source/binary, SPEC, approved/build card copies, and fixed-risk set:
  `6ceba8530`.
- EA registry: `20227,wti-seas-mom1`.
- Magic registry: `XTIUSD.DWX`, slot 0, magic `202270000`.
- Generated resolver: 15,501 rows kept, zero dropped, registry SHA-256
  `9EAD578992E0C0D2224425E24B30DC89FA68B52547672FB28A880DE3CA63D413`.

## Q01 Evidence

- Canonical, approved, and build-time card schema lints: PASS; no missing
  sections or prohibited-library hits.
- EA build authorization guard: PASS for EA ID 20227 and its directory.
- Seven-section SPEC validator: PASS.
- Strict MetaEditor compile: PASS, zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260805_171850/QM5_20227_wti-seas-mom1.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260805_171850/summary.csv`.
- Full strict V5 build check: PASS, zero failures and zero warnings:
  `D:/QM/reports/framework/21/build_check_20260805_171850.json`.
- Follow-up no-compile build check after card synchronization: PASS, zero
  failures and zero warnings:
  `D:/QM/reports/framework/21/build_check_20260805_172026.json`.
- P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_20227/P1/P1_QM5_20227_result.json`.
- EX5 size: 371,522 bytes.

Artifact SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| Source packet | `431635981A0617CE88CA1EF1FDB04C6D782AC09AA561F6D60897F4FDF6E9CA46` |
| Canonical/approved/build card | `B72346DBD1CE94786424E80D2A857E6373930D2EC6A1B4FE97D8139633BFAED5` |
| MQ5 | `707E20C875D352907B343ED37DA4064DD208B252073D6D5E4ED5EBA1BF269238` |
| EX5 | `C9149670378D17A6902898ECD31D26F543E6ADA60F7D5A0820FF593A8865C1FA` |
| SPEC | `DC8BEA8C581943EBABC6A557109F3B9DE6C66D1338845DF4F2BC5664102A8FFE` |
| Backtest set | `7EB7C86F7294BC286BD087F27BE52BF7B98E86AB6B66F132DE2F28CFAA3507A7` |

## Q02 Dry Run And CPU-Ceiling Evidence

The exact no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20227 --symbols XTIUSD.DWX --max-part2-per-run 0

It reported `APPLY=False`, one `never_tested` item selected, zero skipped,
zero stranded, and one priority-track item. Its machine evidence is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json` with `apply=false`,
target EA `QM5_20227`, and target symbol `XTIUSD.DWX`.

At `2026-08-05T17:21:45.1573798Z`, a read-only process scan anchored exactly
to `D:\QM\mt5\T1..T10\terminal64.exe` and explicitly excluding `T_Live`
found eight active factory terminals: T1, T3, T4, T5, T7, T8, T9, and T10.
The binding ceiling was seven. The requested ceiling stop therefore fired
before any apply command, queue write, terminal action, or backtest launch.

## Safety Boundary

- No Q02 apply or manual backtest was run.
- No live, demo, or shadow setfile or deploy artifact was created.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
- No terminal was started, stopped, reserved, reaped, or altered.
- The only post-ceiling action was writing this repository evidence record.
