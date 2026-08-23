# Claude review_ea — QM5_37002 (Gemini first-draft build)

**Router task:** `bd93a4d0-161a-4bba-b8e2-0932119a2060`
**Reviewer:** Claude (headless orchestration cycle), 2026-08-23
**Reason:** `codex_review_required_for_gemini_code`

## Scope

Fresh Gemini first-draft build (not a remediation). Per CLAUDE.md hard
rules, Gemini-authored code requires mandatory Codex review before
acceptance; this is the Claude-side correctness pass and does not
substitute for it. Task stays in `REVIEW`.

## QM5_37002 — dual-thrust-asymmetric-range-breakout (SP500/NDX/XTIUSD, D1)

- **Range calculation**: correct and lookahead-free. `max(HH-LC, HC-LL)` over
  4 closed daily bars (shift 1..4) matches card §2.
- **K1/K2 asymmetry**: genuinely wireable as two independent inputs (not
  silently collapsed to one value) — no defect on the flagged concern, even
  though both default to 0.50 (matches the card's own defaults).
- **MATERIAL divergence — trigger/entry mechanics**: the card specifies a
  pending BUY_STOP/SELL_STOP at `Open_today + k1*Range`. The code instead
  uses **yesterday's** open as the reference and fires a **market** order
  when yesterday's close crosses the band — a lagged, closed-bar
  reformulation of Dual Thrust rather than the card's pending-stop-on-today's-open
  mechanic. Self-consistent and lookahead-free, but not what the card
  specifies.
- **MATERIAL divergence — stop-loss**: card specifies a range-based stop
  (opposite trigger boundary / entry∓0.50×Range). Code uses a 2.0×ATR(14)
  stop instead — and those ATR-stop constants do not appear in the card's
  parameter table at all (card §6.1 lists only Lookback/K1/K2/RiskPercent).
  A substituted risk geometry, not a card-traceable value.
- **Take-profit / exit lifecycle**: card implies ~1:1.5 R:R with a computed
  TP; code sets `req.tp=0.0` (signal-exit only). Card's BE/trailing state
  machine (§5) is unimplemented (`Strategy_ManageOpenPosition` is empty) —
  same pattern as QM5_36008/37001 reviewed earlier today.
- **No-trade filter**: rollover blackout + ATR-spread filter present; the
  card's daily-loss circuit breaker (§3.1.3, ≥2.0%) is absent. An extra
  absolute spread-points cap exists that isn't in the card (not harmful,
  just not traceable to it).
- **GMT/session time-base bug**: `IsRolloverBlackout` builds the 23:55-00:05
  window from `TimeGMT()`, which in the Strategy Tester models broker/server
  time (Darwinex UTC+2/+3), not true GMT — the same class of bug flagged in
  today's QM5_37001 review. The framework's own news gate correctly converts
  internally via `QM_BrokerToUTC`; only this EA's local rollover check
  bypasses it.
- **Unwired-input check**: all 8 `strategy_*` inputs drive real behavior.
  No unwired inputs.
- **Host-slot/magic binding**: bound directly from `qm_magic_slot_offset`.
  `magic_numbers.csv` rows 17455-17457: 3 active rows, slots 0-2
  (SP500/NDX/XTIUSD), magics 370020000-2 — confirmed no overlap with
  QM5_37001's range (370010000-2).
- **Risk mode**: all 3 setfiles `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- **News guardrail**: `qm_news_stale_max_hours=336` — at the ceiling.
- **Build evidence**: `build_check_passed=true`, `compile_succeeded=true`,
  `smoke_result="deferred_p2_smoke"` (confirmed standard sanctioned path
  across every recent build on this box).
- **No ML/no invented values**: only `QM_Common.mqh` include, no ML library,
  no martingale/grid, single position enforced. Caveat: the ATR-stop
  constants (14, 2.0) and the extra absolute spread cap don't trace to the
  card.
- **Look-ahead**: none — range vector, trigger close, and ATR stop all read
  shift≥1; entry gated on `QM_IsNewBar`.

**Verdict: RECYCLE-leaning.** The hard-gate items (magic/slot, risk mode,
news ceiling, no ML, no look-ahead, build evidence, no unwired inputs) are
all clean, but for a mechanical strategy the stop-loss and entry-trigger
mechanics ARE the strategy, and both are substituted rather than
implemented per card: a 2.0×ATR stop with untraceable constants replaces
the card's range-based stop, and a market order on yesterday's-close-cross
replaces the card's pending stop on today's-open. Secondary issues: the
rollover blackout uses broker time instead of true UTC (same bug class as
QM5_37001 earlier today), and the card's daily-loss circuit breaker /
BE/trailing lifecycle are absent.

## Disposition

Task moves to `REVIEW`, not `APPROVED`/`RECYCLE` — Codex must independently
confirm before a RECYCLE disposition is executed, per the standing hard rule
for Gemini-authored code.
