# QM5_41061 WTI Completed-Week NR7 - Q01 And Q02 Capacity Stop

Date: 2026-08-18 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT ENQUEUED - TESTER CAPACITY AND CPU CEILING`

## Candidate And Portfolio Boundary

`QM5_41061_wti-week-nr7-brk` is a low-frequency structural WTI candidate.
It normalizes the Darwinex energy D1 date convention uniformly, requires the
immediately prior broker week to contain exactly one Monday-through-Friday
bar, and compares that week's full high-low range with the six next-older
valid complete weeks. The setup is valid only when the prior week is strictly
narrower than every older selected week. Equality fails.

From broker Tuesday through Friday, the latest completed current-week D1 close
buys strictly above the compressed-week high or sells strictly below its low.
A strict signal consumes one restart-safe broker-week attempt before spread,
quote, ATR, sizing, news, or order gates. The single slot-0 `XTIUSD.DWX`
position uses `RISK_FIXED=1000`, a frozen `3.5 * ATR(20,D1)` hard stop, no
target, and is flat by broker Friday hour 21. Duplicate, malformed, later-week,
and eight-day stale survivors are repaired before entry-only gates.

This direct physical-energy carrier is outside the certified XAU/SP500/NDX/XNG
book. It is not portfolio-admitted or certified by this build. Q02 must first
establish density and economics, and unchanged Q09 alone may establish
realized decorrelation.

## Source, Governance, And Non-Duplicate Review

The reputable-source lineage is Toby Crabel, *Day Trading with Short-Term
Price Patterns and Opening Range Breakout*, Traders Press, 1990. The source
supports narrow-range contraction and subsequent expansion, not this exact
weekly WTI/CFD translation. No source performance claim transfers.

- durable source approval: `908ee9cc8`
- deterministic EA reservation: `3a5984317`
- active slot-0 magic/resolver allocation: `49d8151ce`
- approved Strategy Card and G0 decision: `697e5c752`
- deterministic implementation and Q01 commit: `47a16e738`
- registered route: `XTIUSD.DWX`, D1, slot 0, magic `410610000`

The pre-allocation canonical dedup scan covered 4,548 registry rows and 625
root cards and found no exact identity. Manual family review separated this
rule from the single-D1 NR7 build (`QM5_13096`), current-week first-bar ORB
(`QM5_12965`), inside-week breakout (`QM5_13075`), XAU/XAG close-ratio basket
NR7 (`QM5_41060`), and cumulative-RSI commodity pullback (`QM5_12567`).

## Fixed-Risk Build And Q01 Evidence

- Independent mechanic suite: 13 tests `PASS`. Coverage includes native and
  uniformly shifted energy labels, ambiguous-label rejection, exact previous-
  day chronology, Tuesday-Friday and three-hour clocks, full high-low ranges,
  incomplete immediate-prior rejection, older-holiday skipping, strict range
  equality rejection, upper/lower side, boundary equality, weekend-member
  rejection, and absence of current-bar leakage.
- The canonical and build-directory Strategy Cards are byte-identical and pass
  schema, prohibited-ML, and G0 lint.
- Main-checkout strict MetaEditor compile: `PASS`, 0 errors, 0 warnings. Log:
  `framework/build/compile/20260818_062557/QM5_41061_wti-week-nr7-brk.compile.log`.
- A second strict compile from detached branch commit `47a16e738`, using only
  that commit's clean registry and resolver, also passed with 0 errors and 0
  warnings. Log timestamp: `20260818_063055`.
- Targeted V5 build check: `PASS`, 0 failures, 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260818_062557.json`.
- Static P1 artifact validation: `PASS`:
  `D:/QM/reports/pipeline/QM5_41061/P1/P1_QM5_41061_result.json`.
- Targeted build guardrails: `PASS`, including
  `max_news_stale_hours=336`.
- MQ5 filesystem SHA-256:
  `77F6F486DEC93D12A9FB7E1C0FA8CA17A9A21D44E47B053AC494639246EA99FD`.
- Committed EX5 SHA-256:
  `4F16B325949AD16F077DFD4575712B8EC1D23E9BF34DF45188D502CB29DDFF6E`.
- Backtest-set byte SHA-256:
  `2C1B5D1C81E88CE551F318ACB542DDE04F4A06EE0F553C178C973EBAD12CE0D8`.
- Backtest-set normalized-content build hash:
  `d87d4f7921fa3835e727f67b4d05b5d9f05d5cd08e70997996612daf13815fad`.

No manual tester, smoke test, pipeline-phase runner, dispatcher tick, or
backtest was invoked during Q01.

## Q02 Dry Run And Mandatory Capacity Stop

The target-only canonical dry run selected exactly one fresh Q02 row and no
stranded or recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41061 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The read-only `farmctl.py mt5-slots` census at
`2026-08-18T06:33:06Z` found nine active governed research terminals: `T1`
through `T9`. This exceeds the governed seven-terminal ceiling. `T_Live` and
an unrelated FTMO terminal were observed only so they could be excluded;
neither was touched.

The binding five-sample `GetSystemTimes` whole-host CPU reading ran from
`2026-08-18T06:33:57.8549950Z` through `06:34:08.9419638Z`. Every two-second
sample was `100.0%`; average and maximum were both `100.0%`, above the explicit
`97%` hard host-CPU ceiling.

Per the mission's stop condition, the `--apply` command was not run. The
immediate read-only `farmctl.py work-items --ea QM5_41061` query returned
`count=0`, confirming no Q02 row exists for this EA.

## Safety And Handoff

No Q02 enqueue, dispatcher tick, manual backtest, terminal or worker mutation,
AutoTrading action, live/demo/shadow/stress/optimization preset, `T_Live`
change, deploy or T_Live manifest, portfolio-gate edit, portfolio admission,
decorrelation claim, or correlation waiver occurred.

A later paced operator may repeat the exact target-only dry run and apply only
after fresh governed-terminal and host-CPU checks both pass. Q02 must retire
this identity on zero trades, fewer than five completed positions per full
post-warm-up year, nonpositive governed economics, mixed or ambiguous energy
labels, incomplete immediate-prior week, non-strict NR7, wrong breakout side,
current-bar leakage, duplicate attempt, missing hard stop, weekend hold,
nondeterminism, or invalid fixed-risk mode. The identity must not be tuned to
escape those retirement conditions.
