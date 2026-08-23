# Claude review: QM5_37002 Gemini build

- Review task: `bd93a4d0-161a-4bba-b8e2-0932119a2060`
- Gemini source task: `c0b1b0f0-9945-4aa2-8dc0-43d67c1b1070`
- Source artifact: `C:/QM/repo/artifacts/builds/c0b1b0f0-9945-4aa2-8dc0-43d67c1b1070.json`
- Reviewed source: `framework/EAs/QM5_37002_dual-thrust-asymmetric-range-breakout/QM5_37002_dual-thrust-asymmetric-range-breakout.mq5`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_37002_dual-thrust-asymmetric-range-breakout.md`
- **Verdict: CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff.**

Per hard rule (Gemini-originated code requires mandatory Codex review before acceptance),
this task stays in REVIEW; Claude does not self-approve or advance gemini-originated
builds to PIPELINE. This is the fifth NNFX/breakout-family EA reviewed today; two of its
three findings repeat defect classes found in every prior sibling (QM5_36001, QM5_36004,
QM5_36008, QM5_37001).

## Findings

### 1. High: kill-switch / loss-limit contract entirely absent

Card §4.2 mandates daily hard stop 2.5%, total DD stop 5.0% (§3.1.3 also wants a 2.0% daily
circuit breaker). `OnInit` (lines 262-283) calls only `QM_FrameworkInit`, which applies the
generic default `QM_KillSwitchInit(ea_id, magic, 3.0, 0.0, 1.0)` (`QM_Common.mqh:298`) —
daily 3.0% (wrong number) and total DD **disabled (0.0)**. No explicit
`QM_KillSwitchInit(..., 2.5, 5.0, ...)` call exists anywhere in the source, unlike the
already-remediated siblings (e.g. `QM5_36004.mq5:442`, `QM5_36001.mq5:395`). The approved
drawdown contract is not enforced at all.

### 2. High: OnTick ordering gates protective exits behind the entry filter

`Strategy_NoTradeFilter()` returns early at lines 305-306, before `Strategy_ManageOpenPosition()`
(308) and `Strategy_ExitSignal()` (310). During the rollover blackout or a wide-spread window,
an open position can neither be managed nor exit — the opposite-trigger signal exit and the
time-stop are both suspended exactly when protection matters most. Same backwards-ordering
defect as three of the four prior sibling reviews today.

### 3. Medium: exit lifecycle substitutes an un-carded time-stop and ATR stop, no EOD close

Card §3.4 specifies SL at the opposite trigger boundary (or entry -/+ 0.50xRange) plus an
explicit "close all before daily settlement" EOD exit. The code instead uses an ATR-based hard
stop (`QM_StopATR`, 2.0xATR14, lines 180/186) and a 5-bar max-hold time-stop
(`strategy_max_hold_bars`, lines 242-248) that does not appear in the card, and implements no
EOD close at all. The opposite-trigger soft exit (lines 235-238) is present and correct.

## What is already correct (no defect)

- Trigger levels are plain level comparisons per the card (not a bar-to-bar cross
  requirement), and the code matches: `Close[1] > Buy_Trigger`.
- Rollover blackout correctly uses `TimeGMT()`, 23:55-00:05 window.
- Range/trigger formula matches the card: `Range = max(HH-LC, HC-LL)`, triggers computed
  correctly (lines 102-112). Minor Low-severity note: the reference open used is the shift-1
  bar's open rather than the current day's Open_t — a defensible closed-bar mechanization of
  the Dual Thrust formula, not a look-ahead defect.
- No look-ahead: only shift-1..N closed bars are read, no forming-bar access.
- No ML.
- All 8 strategy inputs plus framework inputs are read (no unwired inputs).
- `qm_news_stale_max_hours = 336` (at the hard ceiling, compliant). Setfile uses
  `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Disposition

Return to the build lane: (1) add `QM_KillSwitchInit(qm_ea_id, QM_FrameworkMagic(), 2.5, 5.0,
1.0)` to `OnInit`, (2) reorder `OnTick` so `Strategy_ManageOpenPosition`/`Strategy_ExitSignal`
run before `Strategy_NoTradeFilter`, (3) reconcile the exit structure against card §3.4 — either
implement the EOD close and remove/justify the un-carded time-stop, or get the card amended if
the ATR-stop + time-stop design is an intentional card gap. Findings #1 and #2 use the identical
fix pattern already applied to QM5_36001/36004 today.
