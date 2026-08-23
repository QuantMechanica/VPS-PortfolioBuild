# Addendum — per-tick full-window recompute in QM5_9961 and QM5_9949 `Strategy_ExitSignal`

Supplements (does not replace) the existing review artifacts:
`docs/ops/evidence/2026-08-23_review_ea_9961_bandy_hma_supertrend_confluence_trend.md`
(task `1bec9666-7684-442f-b85a-982a3a981eb4`, verdict PASS-leaning) and
`docs/ops/evidence/2026-08-23_review_ea_9949_bandy_bbwidth_contraction_breakout_trend.md`
(task `315a0d2d-63aa-46e5-92d1-c0731183a255`, verdict RECYCLE-recommend). Both
router tasks were already independently reviewed and moved to `REVIEW` by a
concurrent claude orchestration lane before this note was written; this is a
supplementary finding for Codex's mandatory review pass, not a router-state
change (the task is not re-claimed, no `update-task` call was made).

## Finding — `claude_review_ea.md` §7 "Per-tick full-window recompute" (block
severity) applies to both EAs and was not flagged in the existing 9961 review

In both `QM5_9961_bandy-hma-supertrend-confluence-trend.mq5` and
`QM5_9949_bandy-bbwidth-contraction-breakout-trend.mq5`, `OnTick()` calls
`Strategy_ExitSignal()` (and, inside it, an unconditional windowed recompute)
**before** the `QM_IsNewBar()` gate:

```
Strategy_ManageOpenPosition();
if(Strategy_ExitSignal())          // <-- runs on every tick
{ ... }
...
if(!QM_IsNewBar())                 // <-- entry signal only gated here
   return;
...
if(Strategy_EntrySignal(req)) { ... }
```

- **QM5_9961** (`QM5_9961_bandy-hma-supertrend-confluence-trend.mq5:279`):
  `Strategy_ExitSignal` calls `Strategy_GetSupertrendStates`, which loops
  `for(idx = copied - 2; idx >= 0; --idx)` over up to `warmup+2` bars
  (default `strategy_warmup_bars=250` → ~252 iterations), calling `QM_ATR`
  once per iteration, on every incoming tick, all day, every day.
- **QM5_9949** (`QM5_9949_bandy-bbwidth-contraction-breakout-trend.mq5:305`):
  `Strategy_ExitSignal` calls `Strategy_GetBBLevels`, which loops over
  `strategy_bb_period` (20) bars via `iClose` to recompute the SMA/stdev,
  again unconditionally on every tick.

Both cases match `claude_review_ea.md` §7 literally: "the function loops
`for(shift = warmup; shift >= 1; shift--)`... and is invoked on every tick
(not gated by `QM_IsNewBar()` or equivalent new-closed-bar detection): block
severity, REJECT_REWORK". This is also semantically pointless, not just
expensive: every value `Strategy_ExitSignal` reads is shift-1 (last **closed**
D1 bar) — `iClose(...,1)`, `iHigh(...,1)`, `iLow(...,1)`, the shift-1 BB/ST
levels — none of which change intraday. Re-running the recompute on every
tick between bar closes cannot change the result; it is pure wasted cost
until the next `QM_IsNewBar()` transition, the exact pattern
`claude_review_ea.md` cites as the cause of the QM5_1044 wall.

Rework directive (for Codex, since Gemini code requires mandatory Codex
review before acceptance per CLAUDE.md): move the exit-signal evaluation
(and its position-closing loop) behind the same `QM_IsNewBar()` gate the
entry signal already uses, or add a local closed-bar check specific to the
exit branch, in both EAs.

## Secondary note — QM5_9949 also has a framework-corset gap independent of the above

`Strategy_CalculateBBWidth`/`Strategy_GetBBLevels` hand-roll Bollinger Band
SMA+stdev via a manual `iClose` loop. The card's own Build-EA note says "BB(20,
2.0) is native MT5: `iBands(...)`", and the framework's pooled reader family
(`claude_review_ea.md` §7) includes `QM_BB_*`. Neither `iBands` nor a
`QM_BB_*` pooled reader is used anywhere in the file — every BB computation,
including the 120-bar compression-window scan in `Strategy_EntrySignal`
(120 × 20 = 2,400 `iClose` calls per new-bar entry check), is bespoke. This
compounds independently of the missing re-arm gate already flagged in the
existing 9949 review artifact.
