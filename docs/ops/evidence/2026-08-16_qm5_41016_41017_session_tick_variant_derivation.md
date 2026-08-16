# QM5_41016 / QM5_41017 session-tick variant derivation

- Router task: `6dfa3117-dc9d-4758-841c-d576020d73e4`
- Branch: `agents/board-advisor`
- Scope: analysis and draft-card proposals only; no card mutation, no source mutation, no build/compile/setfile/work-item creation

## Source finding

`D:/QM/strategy_farm/codex_outbox/QM5_41016_QM5_41017_zero_trades_root_cause_fea371c2_20260816.md`
(router task `fea371c2-bc2c-4601-a9d2-facaafec143a`) diagnosed both approved
cards as `CARD_MISMATCH_SHARED_ENTRY_CLOCK`: entry rule 3 in each card
requires the first observed tick within five minutes of the current D1 bar's
`00:00` label, but XTIUSD's real first tradable tick lands `3,600`-`3,696`
seconds (about 60.0-61.6 minutes) after that label because of the energy
session break. `QM5_41016` lost 53/54 monthly decisions to the gate; its one
"on-time" row was a one-tick Saturday D1 stub whose BUY was broker-rejected
`10018 Market closed`. `QM5_41017` lost 36/36 sign-qualified exact-date rows.
Neither EA's source or card may be patched directly — the review handoff
requires an OWNER-approved variant.

## Draft variants produced

- `D:/QM/strategy_farm/artifacts/cards_review/PENDING_6DFA3117_wti-mclose-mom-session-tick.md`
  (variant of `QM5_41016`)
- `D:/QM/strategy_farm/artifacts/cards_review/PENDING_6DFA3117_wti-dom-ctrreg-session-tick.md`
  (variant of `QM5_41017`)

Both are `status: DRAFT`, `g0_status: PENDING_REVIEW`. Neither authorizes a
build, compile, setfile, work item, or any live/demo/shadow/stress/
optimization/AutoTrading/T_Live action. R2 is left `UNKNOWN` pending
independent G0 review of the redefined clock; R1/R3/R4 carry forward
unchanged from the parent cards since neither the source lineage nor the data
route nor the ML posture changes.

## Design answers to the review handoff's five required decision points

1. **Authoritative clock.** Anchor the entry grace window to
   `D1_bar_open + strategy_session_offset_min` (default `61` min, declared
   range `[55, 70]`) instead of the raw D1 label. The offset is the
   fea371c2-measured value, not an assumption; Development must re-derive it
   from the live bound tick history at build time and treat a materially
   different measurement as build-blocking, never as license to re-widen the
   window silently. `strategy_entry_grace_minutes` stays tight (`10` min)
   around that anchor, preserving the parent cards' falsifiable-attach
   philosophy rather than loosening it into a vague "session window."
2. **Late-attach detection.** The existing persisted attempt ledger (never
   retry the month/date; consume flat on restart with no attempt record) is
   kept as-is. A new orthogonal `strategy_min_attach_ticks` floor (default
   `20` ticks within 5 minutes of the qualifying first tick) is added because
   the ledger alone cannot distinguish a genuine session-open attach from a
   mid-session process restart that also presents as a "first observed
   tick." Flagged explicitly as a falsifiable heuristic for
   Research/Development to validate against the bound XTI tick archive
   before build — not asserted as a QM-certified constant.
3. **Stub-bar handling.** A new `strategy_min_stub_ticks` floor (default
   `20`) on the D1 bar itself excludes thin/weekend/holiday stub bars such as
   the 2018-09-01 one-tick Saturday case that produced the parent card's
   sole (and broker-rejected) qualified attempt.
4. **Per-EA advancement.** `QM5_41016` governs a monthly window with no
   exact-date constraint, so the corrected anchor advances the whole window.
   `QM5_41017` is bound by Borowski's exact numbered-day cells and the
   parent card's explicit never-shift rule; the variant preserves that
   rule exactly — only the within-day attach window moves, and a
   non-tradable day 8/26 still consumes that date flat rather than shifting
   or substituting.
5. **ATTEMPT_STATE diagnostics.** Both variants add four bounded, yearly-reset
   counters (`late_attach_reject_count`, `stub_bar_reject_count`,
   `window_miss_reject_count`, `qualified_entry_count`) so a future Q02
   recovery review has same-window proof without re-deriving logger evidence
   by hand.

## Disposition

Both drafts are proposals only, routed to the normal G0/approve-card path.
No code was touched; no card in `cards_approved` was modified. Left in
`REVIEW` for Research/OWNER; see the companion card-sweep report for the
`XTIUSD.DWX`/`XNGUSD.DWX`-carrier census of every other approved card sharing
this clock idiom.
