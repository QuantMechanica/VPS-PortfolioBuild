# QM5_20222 WTI Seasonal / Return-Sign Concordance Q02 Enqueue

Date: 2026-08-05 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

One new structural, low-frequency energy candidate was researched, approved,
allocated, built, strictly validated, and enqueued once at Q02:

- EA: `QM5_20222_wti-seas-sign`.
- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `202220000`.
- Mechanic: at each broker-month decision, compare WTI's fixed seasonal
  direction (long November-May, short June-October) with the direction from
  the non-negative share of twelve completed monthly returns. Enter only on
  agreement and remain flat on disagreement.
- Direction boundary: BUY winter only when sign probability is at least
  0.40; SELL summer only when it is below 0.40.
- Lifecycle: close before every monthly decision, one consumed attempt per
  month, forty-day stale guard, and frozen `3.5 * ATR(20,D1)` hard stop with
  no target.
- Expected cadence: six to nine packages/year after warm-up; Q02 must retire
  the EA below five completed packages/year.
- Backtest set: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

Q02 work item `92ed552b-bf16-4f8d-bb72-58eda1b554df` was created at
`2026-08-05T08:47:10Z` for `QM5_20222 / XTIUSD.DWX`. The immediate readback
reported phase `Q02`, kind `backtest`, status `pending`, attempt count zero,
and no claim, verdict, or evidence path yet.

## Sources And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/BURAKOV-PAPAILIAS-WTI-SEASIGN-2026/source.md`.

- Burakov, Freidin, and Solovyev (2018), *International Journal of Energy
  Economics and Policy* 8(2), 121-126, supply positive November-May and
  negative June-October WTI seasonal directions.
- Papailias, Liu, and Thomakos (2021), *Journal of Banking & Finance* 124,
  106063, supply the twelve completed monthly return signs, fixed 0.40
  threshold, direction map, and one-month renewal.

Both parent texts have durable complete-read records. Neither tests this
agreement filter, a Darwinex continuous CFD, broker-month reconstruction,
fixed cash risk, an ATR stop, transaction costs, or portfolio correlation. No
source performance statistic is imported as a QM expectation.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,279 registry rows and 395
canonical cards. It found no exact identity or fuzzy match above threshold.
Manual review fixes the load-bearing boundary:

- unconditional winter/summer builds do not require price-state agreement;
- `QM5_13150_wti-signmom` has no fixed seasonal direction;
- `QM5_20221_wti-win-signmom` is symmetric inside winter and flat all summer,
  whereas this EA only buys winter, only sells summer, and is flat whenever
  the two states disagree;
- same-calendar and calendar-trend builds use different formation objects;
  and
- `QM5_12567` is a two-day oscillator pullback.

The fixed seasonal map, twelve binary signs, 0.40 threshold,
agreement-only entry, disagreement-flat state, and monthly renewal are
jointly load-bearing. Q09 alone may establish realized book decorrelation.

## Allocation And Commits

- Source packet, durable G0 decision, and canonical card:
  `4d9088181e39a83a54b5b80192ea77fb5ee0b1a6`.
- Registry and magic allocation, regenerated resolver, EA source/binary,
  SPEC, approved/build card references, and fixed-risk set:
  `446211e9f9d5ec939b729334c04538c77358e0af`.
- Final Q02 status and this evidence: the commit containing this document.
- EA registry: `20222,wti-seas-sign`.
- Magic registry: `XTIUSD.DWX`, slot 0, magic `202220000`.
- Generated resolver: 15,493 rows kept, zero dropped, registry SHA prefix
  `637EDCB280325403`.

## Q01 Evidence

- Canonical and approved card schema lints: PASS; no missing sections or
  prohibited-library hits.
- G0 card lint: PASS.
- EA build authorization guard: PASS for EA ID 20222 and its directory.
- Seven-section SPEC validator: PASS.
- Symbol-scope validator: `SINGLE_SYMBOL_OK`, zero violations.
- Magic-resolver regressions: five passed.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260805_084246/QM5_20222_wti-seas-sign.compile.log`.
- Compile summary:
  `D:/QM/reports/compile/20260805_084246/summary.csv`.
- Strict V5 build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260805_084339.json`.
- EX5 size: 371,686 bytes.

The repository-wide registry validator reports 1,412 pre-existing issues and
exits nonzero. A target-filtered read found zero issue or warning containing
EA 20222, `wti-seas-sign`, or magic `202220000`; no unrelated registry debt
was modified.

Artifact SHA-256 values after the Q02 status update:

| Artifact | SHA-256 |
|---|---|
| Source packet | `91B0A4AD04A1155D7E9FBC2EF3EB23A699609E27D8CCF4A2231DF51F4E3385B4` |
| Canonical card | `2C01BB9EC8E1A2DF4F5FE2AF3FA57843131C11E01EE711B99D48A24765CD4704` |
| Approved card | `2C01BB9EC8E1A2DF4F5FE2AF3FA57843131C11E01EE711B99D48A24765CD4704` |
| MQ5 | `33B1BE6206953FA5B7CA2ABAEF0AE89F4B6F408CD8E5CA4A1FFB1B00A3973B98` |
| EX5 | `BFFADE02721F5DB490197567B262FD52A0AFFA56C19DC36A28E1A2F37ABDDBDF` |
| SPEC | `FB12C19F20CAFBB3CE51ABE708741403C88C5BD7661CC2F73134DAE930A33CC0` |
| Backtest set | `8F95037AD9F59B9D28D1F3A4A6ECF58633BDF4B78321F730C14E083C646936EE` |

## Paced Q02 Enqueue Evidence

The exact no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20222 --symbols XTIUSD.DWX --max-part2-per-run 0

It selected exactly one never-tested row, zero skipped rows, zero stranded
rows, and one priority-track item.

At `2026-08-05T08:47:02Z`, a read-only path-anchored process scan found four
running factory terminals: `T1`, `T2`, `T8`, and `T10`. The binding ceiling
was seven. A second scan inside the guarded apply command at
`2026-08-05T08:47:10Z` again found four, so the command invoked:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20222 --symbols XTIUSD.DWX --max-part2-per-run 0

Apply reported one never-tested item enqueued, zero skipped, zero stranded,
and one priority-track item. Its machine evidence is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json` with `apply=true`.
The canonical `farmctl.py work-items --ea QM5_20222` readback returned exactly
the one Q02 work item recorded above.

## Safety Boundary

- No manual backtest or downstream phase was launched.
- No live/demo/shadow setfile or deploy artifact was created.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
- No terminal was started, stopped, reserved, reaped, or altered.
- Capacity scans used only exact `D:\QM\mt5\T1..T10\terminal64.exe` paths;
  T_Live and unrelated terminals were excluded.
