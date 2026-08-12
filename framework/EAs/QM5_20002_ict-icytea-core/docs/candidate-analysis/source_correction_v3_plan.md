# QM5_20002 source-correction candidate v3 plan

Date frozen: 2026-07-20  
Analysis: `QM5_20002_SHORT_NY_REVERSE_TIME_SCREEN_001`  
Status: **OUTCOME-BLIND SOURCE/CAUSAL/SAFETY CORRECTION; NOT COMPILED OR BACKTESTED**

## Fence and authority

This plan was frozen before changing the MQ5 implementation and without opening
any QM5_20002 tester report, annotated trade workbook, OHLC/tick outcome, or
2017-2021 result. No MT5 process may be started for this plan until the corrected
source, Contract v3 and generated set files have each been committed and their
static checks pass.

The implementation remains a research candidate. Its embedded Strategy Card is
still `status: intake`, not `APPROVED`; therefore this correction must not be
reported as an APPROVED V5 build or as `IN_PIPELINE`. The repository registry
nevertheless already allocates active EA id `20002` and magic numbers
`200020000` / `200020001` for its two registered symbols.

## Primary-source binding and resolved rule

Primary source:

`D:/QM/strategy_farm/artifacts/sources/ict_icy_tea_source_20260716/MQL5_Strategie_Spezifikation_some_icy_tea.docx`

SHA-256:

`8880629e924c7dee48e1d2cd0a5cd835020e057ee592b132b6fd0c7a438231af`

The source defines all session times in New York local time and identifies
previous-day high/low and previous-week high/low as fixed liquidity levels. For
a bullish sweep it permits either (a) a bar whose low crosses below the level
and whose close is back above it, or (b) price returning above it within the
configured 3-5-bar return window; bearish logic is the exact mirror. Structure
break and FVG confirmation are described as events *after* the sweep.

Candidate v3 therefore fixes the causal convention as follows, without any
result-driven parameter choice:

1. Immediate reclaim: the just-closed bar wicks through the level and closes
   back across it. The previous bar's close is irrelevant.
2. Later reclaim: after a closed bar has wicked through a level and closed on
   the swept side, the first subsequent close back across the level is accepted
   if it occurs within `SweepReturnBars` subsequently closed bars. All
   intervening closes must remain on the swept side. The original wick bar,
   extreme and time remain the sweep event.
3. Same-bar sweep and structure-break ordering is not inferred from OHLC. An
   immediate-reclaim bar can create pending sweep state, but a structure break
   must be on a later closed bar. On a later-reclaim bar, the earlier wick makes
   a structure break on the reclaim bar causally admissible.
4. Every candle of a qualifying three-candle FVG must be strictly later than
   the recorded sweep time and no later than the structure-break bar. A
   pre-sweep FVG can neither be selected nor satisfy displacement.

## Corrections fixed before outcomes

- Process the kill switch, invalid pending/fill cleanup, Friday close, open
  position management and strategy day-end exit before news can block new
  entries.
- Cancel the EA's pending entry orders as soon as the current New York time is
  outside the enabled `[start,end)` killzone or either effective calendar's
  fresh high-impact blackout is active. If a fill races cancellation, close the
  invalid new position and retry on later ticks until broker truth is clean.
- Calculate PDH/PDL and previous-week pools from closed M15 bars grouped by an
  explicit DST-aware New York trading date/week, not broker D1/week boundaries.
  The previous day is the most recent completed New York date with data; the
  week is Monday 00:00 through the following Monday 00:00 New York local time.
- Reconstruct confirmed swings causally from closed history after `OnInit`.
  Persist pending structural state transactionally per registered magic/symbol,
  restore it only when its times are non-future and within the existing expiry,
  and delete stale/incomplete state.
- Reconstruct partial-close state from position deal history and breakeven state
  from the current broker stop loss. A restart after partial close but before a
  successful breakeven modification must retry only the missing breakeven step.
- Keep all existing inputs, risk settings, 30-bar engineering expiry, screen
  arms, symbols and dates unchanged. These corrections introduce no optimized
  value and do not change generic framework files.

## Ambiguities deliberately not guessed

The primary source does not specify a numerical maximum sweep-to-MSS lifetime,
which exact one of multiple post-sweep FVGs must be selected, or how a rejected
broker send should affect the one-shot structural setup. Candidate v3 preserves
the existing 30-bar expiry, existing FVG selection direction and existing
one-shot send semantics. They remain engineering assumptions and may not be
tuned after results are viewed.

The source also does not establish that EURUSD and GBPUSD are diversified
portfolio sleeves or that this candidate can pass an FTMO evaluation. Those are
empirical questions for a later preregistered test and joint portfolio analysis.

## Required freeze sequence

1. Commit this plan alone.
2. Implement only the corrections above under `QM5_20002`, add local static
   tests, and commit the corrected implementation.
3. Freeze Contract v3 to the exact implementation commit and source hash.
4. Update the local generator/auditor bindings, regenerate the four exact set
   files and manifest, and run static tests plus deterministic generation check.
5. Stop. A fresh standard compile and any MT5/backtest execution require a new
   explicitly authorized outcome phase after this complete freeze.

