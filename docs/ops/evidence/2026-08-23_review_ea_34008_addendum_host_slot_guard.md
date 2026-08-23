# Addendum — missing host-symbol/primary-slot guard in QM5_34008 `Strategy_NoTradeFilter`

Supplements (does not replace) `docs/ops/evidence/review_ea_qm5_34008_2026-08-23.md`
(task `f53fcf1d-e179-47c4-8571-40430b61aff1`, verdict PASS-leaning). That router task
was already independently reviewed and left in `REVIEW` by a concurrent claude
orchestration lane before this note was written; this is a supplementary finding for
Codex's mandatory review pass, not a router-state change (the task is not re-claimed,
no `update-task` call was made).

## Finding — Q02 will fan this EA across all 7 registered symbols, but `Strategy_EntrySignal`'s
basket-dispersion logic is not gated to a single host/anchor symbol, so all 7 per-symbol
backtest runs will independently fire the same basket signal

`QM5_34008_multicurrency-basket-dispersion-hedger.mq5:125-144` (`Strategy_NoTradeFilter`)
only checks time-of-day and the current `_Symbol`'s spread/ATR ratio. It does **not**
check that `_Symbol` (or `qm_magic_slot_offset`) matches a designated host/primary
leg, unlike every other basket EA in this framework that computes a signal from a
fixed multi-symbol array and opens orders across symbols from a single chart context:

- `QM5_10024_rw-fx-comm-basket.mq5:301-306`: `Strategy_NoTradeFilter` derives
  `leg = Strategy_LegIndexForSymbol(_Symbol)` and returns `true` (no trade) unless
  `qm_magic_slot_offset == g_leg_slots[leg]`.
- `QM5_1017_chan_pairs_stat_arb.mq5:483`: `if(_Period != PERIOD_D1 || _Symbol !=
  g_pair_symbols[0]) return true;` — `STRATEGY_PRIMARY_SLOT` is a fixed `#define`
  (line 37), not derived from the run's own symbol. Of its 40 per-symbol setfiles,
  only the one anchored on `g_pair_symbols[0]` can trade; the rest are architecturally
  guaranteed zero-trade.
- `QM5_12821_twin-csm-basket.mq5:1017,1021` — the exact sibling the existing
  QM5_34008 review artifact cites for the "always `return false`" convention check —
  has `if(_Symbol != QM12821_HOST_SYMBOL) return true;` and
  `if(qm_magic_slot_offset != 0) return true;` in its own `Strategy_NoTradeFilter`.

QM5_34008 has none of this. `magic_numbers.csv` registers all 7 symbols
(`framework/registry/magic_numbers.csv:17393-17399`, slots 0-6), and
`sets/QM5_34008_multicurrency-basket-dispersion-hedger_<SYMBOL>.DWX_H1_backtest.set`
exists for each — meaning Q02 will run this EA as 7 separate, isolated MT5 Strategy
Tester backtests, one per registered symbol. `Strategy_EntrySignal`'s basket
computation reads a fixed `g_basket_symbols[]` array (lines 50-58) and does not
depend on `_Symbol` or `qm_magic_slot_offset` at all — so every one of the 7 runs
independently evaluates the identical dispersion condition over the identical 7-pair
data and, whenever it fires, opens the identical two-leg package (same `sym_a`/`sym_b`,
same direction). The 7 runs will not be independent per-symbol evidence; they will be
7 correlated re-derivations of the same signal, differing only in which symbol's tick
stream drives `OnTick()` timing and which symbol's spread feeds the
`Strategy_NoTradeFilter` ATR/spread check.

This violates the evidence-integrity assumption Q02-Q10 fanout relies on (Hard Rule:
evidence over claims) — 7 per-symbol PASS/FAIL rows would be recorded as if
independent, when 6 of them are architecturally supposed to be genuine no-signal
(the `ZT XAU/UK100/SP500` class already seen for `QM5_1017` and documented in
`project_qm_1537_rescue_reviews_closed_2026-08-15` — "GENUINE no-signal, NIE
requalifizieren") and are not, because the guard that produces that genuine no-signal
result in every sibling basket EA is absent here.

Rework directive (for Codex, since Gemini code requires mandatory Codex review before
acceptance per CLAUDE.md): add a host-symbol or primary-slot guard to
`Strategy_NoTradeFilter`, matching the `QM5_12821_twin-csm-basket` pattern it already
claims to follow — e.g. `if(qm_magic_slot_offset != 0) return true;` (slot 0 =
`EURUSD.DWX`, the card's documented `primary_target_symbols`) — so only the
EURUSD.DWX-anchored run trades and the other 6 per-symbol Q02 runs correctly resolve
to architectural zero-trades instead of duplicating the same package.

## Scope note

Everything else in the existing review artifact (unwired-input check, magic/slot
registry consistency, risk/news guardrail compliance, the "always `return false`"
convention check itself) was independently re-derived while investigating this finding
and holds up — this addendum narrows to the one gap the sibling-EA comparison did not
extend to.
