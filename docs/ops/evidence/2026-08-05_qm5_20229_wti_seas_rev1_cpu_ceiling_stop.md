# QM5_20229 WTI Physical-Season Pullback Build And CPU-Ceiling Stop

Date: 2026-08-05 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

One new structural, low-frequency direct-energy candidate was researched,
approved, allocated, built, and strictly validated:

- EA: `QM5_20229_wti-seas-rev1`.
- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `202290000`.
- Mechanic: BUY November-May only after the exact immediately completed
  broker-calendar month had a negative WTI return; SELL June-October only
  after that completed return was positive; consume the month and stay flat
  when the return agrees with the seasonal direction.
- Lifecycle: close before the next broker-month decision, with a forty-day
  stale guard and no intramonth re-entry.
- Risk: frozen `3.5 * ATR(20,D1)` server-side hard stop, no target,
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
- Expected cadence: five to seven completed packages/year; Q02 must retire
  below five/year.

The Q02 dry run selected exactly one `never_tested` priority item and no
stranded/recovery item. Q02 was **not enqueued** because the active factory
terminal count had reached the binding backtest CPU ceiling. No Q02 result,
profitability, decorrelation, certification, or portfolio-admission claim is
made.

## Source And Non-Duplicate Boundary

The governed source packet is
`strategy-seeds/sources/BURAKOV-YANG-WTI-SEASREV1-2026/source.md`.

- Burakov, Freidin, and Solovyev (2018), *International Journal of Energy
  Economics and Policy* 8(2), 121-126, supply positive November-May and
  negative June-October WTI physical-season directions.
- Yang, Goncu, and Pantelous (2017), "Momentum and Reversal in Commodity
  Futures," SSRN 3069253, supply the academic fixed-horizon commodity-
  reversal lineage.

Both parent texts have durable complete-read repository records. Neither
tests this interaction, a Darwinex continuous CFD, fixed cash risk, costs, or
portfolio correlation. No source performance statistic transfers.

The deterministic pre-allocation helper found no exact identity and the two
expected `wti-seas-*` fuzzy-family matches. Manual review resolves them:

- `QM5_20227_wti-seas-mom1` requires the completed-month sign to agree with
  the physical-season map. This candidate requires the mutually exclusive
  opposing state and still enters in the seasonal direction.
- `QM5_20226_wti-seas-dow` uses a weekday event and one-session hold rather
  than an exact completed-month counter-move and month-to-month hold.
- `QM5_20137_wti-seas-pb` estimates direction from prior same-calendar
  returns; this candidate uses the fixed Burakov map.
- `QM5_20218` and `QM5_20214` trade both reversal directions in one disjoint
  season; this candidate takes only the seasonal-direction half in each
  season and covers the full calendar.
- Unconditional seasonal, twelve-sign breadth, medium-horizon reversal, and
  two-day oscillator builds have different formation objects or entry maps.

The fixed two-season map, exact prior broker month, opposing-sign gate,
seasonal entry direction, agreement-flat state, and monthly renewal are
jointly load-bearing.

## Allocation And Commits

- Approved source packet and durable G0 decision: `6bd24168d`.
- Canonical card and EA-ID allocation: `a8f0997f2`.
- Magic slot allocation and regenerated resolver: `c0d6e7b4d`.
- EA source/binary, SPEC, approved/build card copies, and fixed-risk set:
  `523c453da`.
- EA registry: `20229,wti-seas-rev1`.
- Magic registry: `XTIUSD.DWX`, slot 0, magic `202290000`.
- Generated resolver: 15,504 rows kept, zero dropped, registry SHA-256
  `A5A288D65A782788021A8A41148DC24AA707FC8B06BC4934360217C435880448`.

## Q01 Evidence

- Canonical, approved, and build-time card schema lints: PASS; no missing
  sections or prohibited-library hits.
- G0 readiness lint: PASS.
- EA build authorization guard: PASS for EA ID 20229 and its exact directory.
- Seven-section SPEC validator: PASS.
- Strict MetaEditor compile: PASS, zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260805_181638/QM5_20229_wti-seas-rev1.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260805_181638/summary.csv`.
- Final strict V5 build check: PASS, zero failures and zero warnings:
  `D:/QM/reports/framework/21/build_check_20260805_181810.json`.
- P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_20229/P1/P1_QM5_20229_result.json`.
- EX5 size: 371,690 bytes.

Artifact SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| Source packet | `FEC2477BDF28497F83D90429F0043C15BE0F4F7274410F0FBB928E016A787D5C` |
| G0 decision | `9D98A11E091220F0786080DEE456659DD2338D28C35CEC8D1F420CA421B6D362` |
| Canonical/approved/build card | `94DF08128531849FD7595C13B55D61D81CCD2C8565A8CF777DDABFD0328BA57F` |
| MQ5 | `9797E9ED0BE8E903DD92AC1461B808A22B7FF315FE9CD59B25936486716E7B9B` |
| EX5 | `7F7D0DD1A060584121C55B93102164196C0FE20C3D8F80540B63CD086A25D0E7` |
| SPEC | `48FD360B58D9C5764A8A9EF171ED701CA376868DBDE1D62069A16D6F5B1C126D` |
| Backtest set | `B6620E64741033FEA5DBD836C0EE01C3153719F390A2B2056FF9D0EF8C45CF74` |

## Q02 Dry Run And CPU-Ceiling Evidence

The exact no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20229 --symbols XTIUSD.DWX --max-part2-per-run 0

It reported `APPLY=False`, one `never_tested` item selected, zero skipped,
zero stranded, and one priority-track item. Its machine evidence is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json` with
`apply=false`, target EA `QM5_20229`, and target symbol `XTIUSD.DWX`.

At `2026-08-05T18:20:11.9270573Z`, a read-only process scan anchored exactly
to `D:\QM\mt5\T1..T10\terminal64.exe` and explicitly excluding `T_Live`
found seven active factory terminals: T2, T3, T4, T5, T8, T9, and T10. The
binding ceiling was seven. The OWNER instruction requires a stop when that
ceiling is hit, so no apply command, queue write, terminal action, or backtest
launch followed.

The immediate read-only command
`python tools/strategy_farm/farmctl.py work-items --ea QM5_20229` returned
`count: 0`, confirming that no Q02 work item exists.

## Safety Boundary

- No Q02 apply or manual backtest was run.
- No live, demo, or shadow setfile or deploy artifact was created.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
- No terminal was started, stopped, reserved, reaped, or altered.
- The only post-ceiling repository action was writing this evidence record.
