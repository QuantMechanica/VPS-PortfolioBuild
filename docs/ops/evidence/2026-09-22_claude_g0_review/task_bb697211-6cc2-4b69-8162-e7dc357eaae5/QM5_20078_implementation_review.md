# QM5_20078: independent implementation review after G0 amendment

Task: `bb697211-6cc2-4b69-8162-e7dc357eaae5` ("Independent POC 20078 implementation
review after G0 amendment"), reviewing commit `cfa03950b07013b1b18683b3e4c0c9a69e65d58c`
in `C:/QM/worktrees/codex-ftmo-recovery-20260922`, published scoped source at
`C:/QM/repo/framework/EAs/QM5_20078_volume-profile-poc-retest-intraday/`. G0 wording
amendment already independently accepted by task `6c5219a9` (see
`docs/ops/evidence/2026-09-22_claude_g0_review/QM5_20078_g0_acceptance.md`). This review
is a separate, later act: does the *implementation* faithfully execute the amended card,
and are the two disclosed implementation conventions acceptable.

## Disposition: ACCEPTED — no correction required

Builder is codex (`751d8eb5` build lane); this review does not self-approve a codex build
and grants no pipeline/live promotion. It confirms the implementation for the record and
answers the two explicit adjudications the task payload required.

## 1. Explicit adjudication: hard 2ATR cap vs. closing-bar VA target

**Card text** (Exit section): TP(BUY) is `close` reaching `VAH_prior` on a closing bar
(near target); TP cap(BUY) is a "hard cap at `entry + 2.0×ATR14_M15`"; "Whichever level
is reached first (by `close`) closes the trade." Read as one uniform close-evaluated
rule, the final sentence would require the 2ATR cap to also be a close-only check.

**Implementation** (`QM5_20078_volume-profile-poc-retest-intraday.mq5`):
- `req.tp = entry ± strategy_tp_atr_mult(2.0) × atr` is set as the position's broker-side
  TP order at entry (line 256) — a true hard limit, fillable intrabar, not evaluated only
  on bar close.
- The VAH/VAL target is a *separate*, manually-evaluated exit checked once per completed
  M15 bar in `Strategy_ExitSignal()` (line 289): `buy ? close>=g_vah : close<=g_val`.
- SPEC.md discloses this explicitly ("Hard TP is E +/-2A. A completed close reaching VAH
  (BUY)/VAL (SELL) exits sooner when that target is nearer.") — not a silent deviation.

**Adjudication: ACCEPT the hard-cap-as-broker-order reading.**
- The card's own word "hard cap" (and the parallel "Hard SL — no widening after entry",
  which is unambiguously a broker-side order in this framework's convention) supports a
  broker-enforced ceiling, not a second close-only check.
- It is the risk-safer reading: a close-only cap would let the position run beyond
  entry±2ATR intrabar on any bar that spikes through the cap and reverses before close —
  undisclosed extra risk that a genuinely "hard" cap is meant to prevent, and one that
  matters for FTMO daily-loss-limit compliance.
- It does not change the near-target economics: VAH/VAL still exits first whenever it is
  the nearer level, exactly as the card intends — the broker TP order only ever binds
  when price reaches the cap before any qualifying close event fires.
- Non-blocking follow-up recommended (not required for this build): reword the card's
  final TP sentence to drop the "(by close)" qualifier from the cap clause, so a future
  reader does not re-derive this ambiguity. No economic content changes if this wording
  fix is made later.

## 2. Explicit adjudication: news window PRE30_POST30 vs. card's PRE15_POST15

Card: "skip new entries in the 15 min before / 15 min after high-impact news."
Implementation default: `input QM_NewsTemporalMode qm_news_temporal =
QM_NEWS_TEMPORAL_PRE30_POST30;` — the framework does not expose a PRE15_POST15 mode.

**Adjudication: ACCEPT explicitly (not silently).** PRE30_POST30 is a strict superset of
PRE15_POST15 — every entry the card's 15-minute rule would block is also blocked by the
30-minute window; the deviation only removes a small number of additional entries inside
the 15–30 minute band around news, tightening the filter rather than loosening it. This is
not the "silently approve an economic deviation" pattern the task payload warned against:
it is a disclosed, conservative default (SPEC.md §"News boundary"), and both axes remain
governed Q09 inputs for future sweep testing, so the card's literal 15-minute window can
still be measured later without a code change.

## 3. Card-fidelity cross-check (source-level, independent re-derivation)

Read `QM5_20078_volume-profile-poc-retest-intraday.mq5` end to end (337 lines) against
the amended card and SPEC.md line by line, not via the commit message summary:

| Card/SPEC requirement | Source location | Verified |
|---|---|---|
| Prior session 06:00–21:00 broker time, Monday→Friday, weekends skipped | `Strategy_SessionStart`, `Strategy_LoadProfile` (walks back over `day_of_week==0\|\|6`) | PASS |
| M1 midpoint binning, 50 fixed bins, high-endpoint clamps to bin 49 | `Strategy_ProfileFromRates` (`MathMax(0,MathMin(49,bin))`) | PASS |
| POC tie → lower-index bin | strict `>` comparison in POC scan (later equal bins never win) | PASS |
| VA tie → lower price first during 70% accumulation | explicit tie-break in the selection sort (`order[j]<order[best]`) | PASS |
| VAL/VAH = outer boundaries of selected bin set | `g_val=lower+lo*width; g_vah=lower+(hi+1)*width` | PASS |
| <60 positive-volume M1 bars disables next session | `positive<strategy_min_profile_bars` → `g_profile_valid=false` | PASS |
| First down/up-touch consumes side for the session, independent of later filters | `Strategy_ReplayTouches` (`buy_consumed`/`sell_consumed` latch across the full from-scratch replay) | PASS |
| Restart reconstruction (no reliance on sticky in-memory flags) | Replay recomputes touch state from `Strategy_SessionStart` through the current closed bar on every call — never persisted/incremental | PASS |
| First-hour touch can consume but not admit entry | `count<strategy_min_session_bars` clears `g_buy_event/g_sell_event` *after* consumption is computed | PASS |
| Indicators read from completed bar (shift 1), card `[0]`→MT5 shift 1 | `QM_IndicatorWarmupReady(...,0,1,...)` + `QM_ATR/EMA/RSI(...,1)` for ATR-M15, ATR-D1, EMA-H1, RSI-M15 | PASS |
| VA-width sanity ≥0.5×ATR14(D1) | `g_vah-g_val<strategy_va_min_atr_d1*daily_atr` reject | PASS |
| Amended SL: BUY=max(E−A,P−0.5A), SELL=min(E+A,P+0.5A) | `Strategy_StopPrice` — exact formula match | PASS |
| SL<E, E>P (BUY) / SL>E, E<P (SELL) enforced | final guard in `Strategy_EntrySignal` + POC-side quote check | PASS |
| Session-close exit every tick, ahead of entry/news filters | `Strategy_ManageOpenPosition()` called unconditionally before the new-bar gate in `OnTick` | PASS |
| Time-stop = 24 actual M15 bars | `iBarShift(...)` age check in `Strategy_ExitSignal`, `strategy_max_hold_bars=24` | PASS |
| One position per magic | `QM_TM_OpenPositionCount(QM_FrameworkMagic())>0` in `Strategy_NoTradeFilter` | PASS |
| RISK_FIXED>0 / RISK_PERCENT=0 in backtest sets | all 7 `.set` files: `RISK_FIXED=1000`, `RISK_PERCENT=0` | PASS |

No discrepancy found beyond the two explicitly-flagged, explicitly-disclosed conventions
adjudicated above.

## 4. Independent test re-execution (not trusted from the commit message)

Re-ran the suite myself rather than accepting the claimed "2 passed / 33 assertions":

```
python -m pytest tools/strategy_farm/tests/test_qm5_20078_poc.py -v
tools/strategy_farm/tests/test_qm5_20078_poc.py::test_actual_profile_touch_stop_and_entry_boundaries PASSED
tools/strategy_farm/tests/test_qm5_20078_poc.py::test_protection_and_consumption_precede_entry_filters PASSED
2 passed in 2.38s
```

`test_actual_profile_touch_stop_and_entry_boundaries` transliterates the actual
`Strategy_ProfileFromRates`, `Strategy_ReplayTouches`, `Strategy_StopPrice`,
`Strategy_EntrySignal` function bodies (regex-extracted from the real `.mq5`, not
hand-copied) into executable C#, then asserts 33 boundary conditions: POC/VA tie-breaks,
bin-49 clamp, sparse-session rejection, all 5 SL worked examples from the card, exact-
touch equality on both sides, restart-replay non-rearm, first-hour consume-without-admit,
RSI boundary exclusion (45/55), NaN-indicator fail-closed, POC-side quote rejection,
VA-width guard, and the mirrored SELL path. `test_protection_and_consumption_precede_entry_filters`
independently asserts the source-code ordering claims (session-close before new-bar gate,
touch-consumption before the min-session-bars filter, exit-signal before news) by string
index rather than by re-reading the code manually, plus a clean `build_gate_hardening`
guardrail pass (no failures, no warnings).

## 5. Compile authentication check (no ad hoc MetaEditor launched, per instruction)

Queried `D:/QM/strategy_farm/state/farm_state.sqlite` `work_items` directly for
`17501e85-c8d5-4379-a8f8-95f73a284626` rather than re-invoking the compiler:

- `status=done`, `verdict=COMPILE_OK`, `compile_result.build_check_result=PASS`,
  `compile_result.compile_result=PASS`, `setfile_count=7`, `failure_classes=[]`.
- `mq5_sha256 = 6a902810b1ae3a3aa29391d74f66b872f8aa0cc688afae7d8088d9304103774d`
- `ex5_sha256 = afffb5b4a4347fbdb391babdd93940b42b062570de84b2d17ca5effb7eb30c68`
- `risk_contract = {RISK_FIXED: 1000.0, RISK_PERCENT: 0.0}` — matches the set files.

Independently recomputed the source hash on both the reviewed worktree copy and the
published canonical copy — both match the compiled `mq5_sha256` exactly, confirming no
drift between what was reviewed, what was compiled, and what is now in `C:/QM/repo`:

```
sha256sum .../codex-ftmo-recovery-20260922/framework/EAs/QM5_20078.../QM5_20078....mq5
  -> 6a902810b1ae3a3aa29391d74f66b872f8aa0cc688afae7d8088d9304103774d
sha256sum C:/QM/repo/framework/EAs/QM5_20078.../QM5_20078....mq5
  -> 6a902810b1ae3a3aa29391d74f66b872f8aa0cc688afae7d8088d9304103774d
```

## Scope and limits

This review is source-level and test-level fidelity only. It is not a backtest, not a
profitability claim, and not a Q-gate verdict — none is implied. No AutoTrading, T_Live,
pipeline-stage, or live-promotion action was taken. The COMPILE_EA artifact above pre-
dates this review and is cited as authentication only, not produced by this task. Actual
governed smoke/Q02 intake for QM5_20078 remains a separate, still-pending step per
`docs/ops/evidence/2026-09-22_ftmo_recovery/README.md`.
