# QM5_1630 demark-td-sequential-combo-overlay-h4 — Claude code review

- **Task:** review_ea `cbd1ece7-9433-43c4-aa54-43c9661e1b34` (source_agent: gemini, source_execution_backend: agy)
- **Card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1630_demark-td-sequential-combo-overlay-h4.md`
- **Reviewer:** Claude, 2026-08-10
- **Verdict:** NEEDS_FIX (3 preflight-blocking gaps + 2 restart-safety defects); left in REVIEW per Hard Rule "Codex review is mandatory before acceptance" — not self-approved to APPROVED/PIPELINE.

## Mechanical verification (independently re-run, not trusted from source_verdict)

- `.mq5`/`.ex5` present, canonical `QM5_1630_demark-td-sequential-combo-overlay-h4` naming correct.
- `magic_numbers.csv` has all 4 rows (16300000-16300003, EURUSD/GBPUSD/USDJPY/XAUUSD.DWX, `reserved_by: Gemini`) — consistent with card's 4 `target_symbols`. No collision.
- Source build result (`D:/QM/strategy_farm/artifacts/builds/1af5d4c8-737b-4e19-84e4-2e34174cd5d5.json`): `build_check_passed: true`, `compile_succeeded: true`, `smoke_result: "deferred_p2_smoke"` — sanctioned pattern ([[project_qm_deferred_p2_smoke_review_inconsistency_2026-07-19]]), informational only, not itself blocking.

## Finding 1 [block]: no `ea_id_registry.csv` row

`framework/registry/ea_id_registry.csv` has no active row for ea_id 1630. The registry
preflight this gate exists to guarantee (deterministic ea_id↔slug↔source_id binding) is
incomplete. Same defect class Codex's independent review flagged as `block` for sibling
QM5_1627 (`docs/ops/evidence/2026-08-10_qm5_1627_codex_gemini_review.json`, finding 6).

## Finding 2 [block]: `SPEC.md` missing

`framework/EAs/QM5_1630_demark-td-sequential-combo-overlay-h4/` has no `SPEC.md`.
`validate_spec_doc.py` requires it (7 section headers) and blocks Q02 promotion on
`fail_code=spec_validation_failed` per the Q01 Build & Spec gate. Same defect Codex
flagged for QM5_1627 (finding 7).

## Finding 3 [block]: setfiles missing entirely

`framework/EAs/QM5_1630_demark-td-sequential-combo-overlay-h4/sets/` is empty. The build
result's own `setfiles_generated: []` confirms none were produced for any of the 4
registered symbols. The Q02 phase runner exits FATAL with "no setfiles match pattern"
without these — this EA cannot enter the pipeline as-is.

(Findings 1-3 are the same three-item gap on both `review_ea` tasks routed this cycle —
see the companion QM5_1628 review below. This looks like a systematic omission in the
current Gemini/agy build path, not an isolated one-off — worth flagging to whoever owns
that build prompt, not just fixing per-EA.)

## Finding 4 [warn]: TD-Sequential/Combo accumulator state cold-starts on every restart

`OnInit` (lines 681-707) unconditionally zeroes all `g_seq_*`/`g_combo_*` setup and
countdown counters — there is no historical rebuild. TD-Sequential/Combo is inherently
an accumulating multi-bar state machine (9-bar setup → 13-bar countdown for Sequential,
10-bar setup → 13-bar countdown for Combo — up to ~22+ H4 bars of continuous history
needed to reach a signal). Every EA restart, recompile, or terminal-worker respawn
(all of which are documented as occurring on this farm — session-loss/RDP incidents,
VPS reboots, `QM_StrategyFarm_TerminalWorkers_AT_STARTUP`) silently discards any
in-progress setup/countdown and forces a multi-day cold-start before the overlay signal
can fire again. Card doesn't authorize or even discuss this; given the card's own
conservative 2-5 trades/year/symbol frequency, repeated cold-starts are a plausible,
material source of missed trades over the EA's life. Fix: rebuild `g_seq_*`/`g_combo_*`
from N bars of history in `OnInit` (replay `AdvanceState()`'s logic bar-by-bar), or at
minimum document this as an accepted limitation.

## Finding 5 [warn]: time-stop counter is not restart-safe

`g_bars_in_trade` (incremented once per bar in `AdvanceState()`, line 399-402) drives
the 60-bar time-stop (`Strategy_ExitSignal`, line 635-636) but resets to 0 in `OnInit`
(line 705). An EA restart mid-trade silently resets the time-stop clock, extending the
effective hold time control past the card's specified 60 H4 bars. Contrast with the
companion QM5_1628 build in this same batch, which correctly derives its time-stop from
`iBarShift(_Symbol, PERIOD_H4, PositionGetInteger(POSITION_TIME), false)` — restart-safe
by construction. Same defect class Codex flagged as significant for QM5_1627 (finding 5:
"time stop restarts... after restart"). Fix: use the framework's restart-safe
`QM_TM_HeldPeriods(_Symbol, PERIOD_H4, PositionGetInteger(POSITION_TIME))` instead of
the hand-rolled counter.

`g_partial_close_done` (line 108, 593) has the same restart-reset issue: if price is
still past the 50%-of-TD-Risk-Level zone after a restart, the EA will attempt a second
50%-of-current-volume partial close on an already-reduced position. Lower severity
(the position only gets smaller than intended, not larger/riskier) but a real logic gap
in the same family as Finding 5.

## Card-fidelity checks that passed (no defect)

- Entry: Sequential countdown-13 completion + Combo phase confluence (`countdown_active`
  bars 5-10, or completed within trailing 8 bars) + D1 SMA(200) regime gate — matches
  card's overlay pseudocode exactly (`AdvanceState()` lines 147-201, `Strategy_EntrySignal`
  lines 481-541).
- Exit: TD-Risk-Level TP/SL via `CalculateTDRiskLevel` (highest-true-range bar in the
  setup→countdown window, ± that bar's TR, ATR-capped at 3.0×) matches card's published
  Perl 2008 formula.
- Trailing: BE-move at +1.5×ATR(14) profit (`strategy_trailing_atr_mult=1.5`), 50%
  partial-close at 50%-of-TD-Risk-Level — both match card.
- Sequential-recycle exit (new same-direction setup within 18 bars of entry) — matches
  card's "TD Recycle qualifier" exit.
- Cooldown 18 bars, spread filter 0.3×ATR, one-position-per-magic, news filter wiring —
  all match card / framework convention. No raw `iATR/iMA/iRSI/iMACD/iADX/iBands` calls
  (uses `QM_ATR`/`QM_SMA` correctly); raw `iOpen/iHigh/iLow/iClose/iTime/iBarShift` usage
  throughout the Sequential/Combo state machine is legitimate bespoke structural logic
  per the Framework Corset exception (no `QM_*` abstraction exists for DeMark bar-counting)
  but is not tagged `// perf-allowed` per the corset's documentation convention — cosmetic,
  not re-listed as a separate finding.
