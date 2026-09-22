# QM5_20078: designated G0 acceptance of the closer-stop clarification

Task: `6c5219a9-ed29-4e82-acd0-ca949571271f` ("Resolve QM5_20078 contradictory stop
equation and resume existing approved-card build"), decision reference
`decisions/2026-09-21_owner_ftmo_full_throttle_research.md`.

## Disposition: ACCEPTED (no alternative equation required)

The proposal in `C:/QM/repo/docs/ops/evidence/2026-09-22_ftmo_recovery/QM5_20078_card_clarification.md`
is accepted as the durable amendment, verbatim on the equations. It has been persisted
into the card of record:
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_20078_volume-profile-poc-retest-intraday.md`
(Stop Loss section rewritten, Implementation boundary conventions section added,
`last_updated: 2026-09-22`, lessons-learned entry appended). This card has no repo
mirror under `C:/QM/repo/artifacts/cards_approved/` — D: is the sole location, confirmed
by direct lookup before editing (`feedback_cards_approved_dual_location_2026-08-23`
memory: check both locations before concluding either).

## Why accepted rather than amended further

1. **Contradiction is real and precisely identified.** Original text: "SL is the
   MINIMUM of (1 ATR below entry) and (0.5 ATR below the POC line) — whichever is
   closer." For a BUY (stop below entry), the price-minimum of two sub-entry levels is
   the level *farther* from entry; "whichever is closer" picks the *nearer* level. These
   are opposite selections whenever `E − A ≠ P − 0.5×A`. The SELL side of the original
   card already reads unambiguously as "whichever closer" with no MINIMUM-of-price
   framing, so the asymmetry was BUY-side wording only, not a designed asymmetry.
2. **Proposed fix restores symmetry and matches the disambiguated SELL text.**
   `BUY SL = max(E−A, P−0.5A)`, `SELL SL = min(E+A, P+0.5A)` is exactly "closer to
   entry" (minimum stop *distance*) expressed as a price formula, for both sides.
3. **Numeric verification (recomputed independently, not copied from the proposal):**

   | Side | E | A | P | Candidate 1 (entry-anchored) | Candidate 2 (POC-anchored) | SL = closer |
   |---|---:|---:|---:|---:|---:|---:|
   | BUY | 101 | 4 | 100 | 97 | 98 | max(97,98) = **98** |
   | BUY | 105 | 4 | 100 | 101 | 98 | max(101,98) = **101** |
   | BUY | 102 | 4 | 100 | 98 | 98 | max(98,98) = **98** (tie) |
   | SELL | 99 | 4 | 100 | 103 | 102 | min(103,102) = **102** |
   | SELL | 95 | 4 | 100 | 99 | 102 | min(99,102) = **99** |

   All five rows match the proposal's table; no arithmetic error found. Each result is
   the level nearer to `E`, confirming the formula implements "whichever closer" and not
   "minimum price."
4. **No economic content changed.** R1-R4 assessment, target_symbols, expected trade
   frequency, TP construction, position sizing, and `g0_status: APPROVED` are untouched —
   this is a wording/arithmetic-fidelity fix on an already-approved card, consistent with
   the reviewer authority granted in the task payload ("As designated G0 authority,
   accept and persist a precise amendment").
5. **Implementation boundary conventions accepted alongside** (session window,
   bin-midpoint/tie-break rules, touch-consumption/re-arm semantics including restart
   reconstruction, indicator-timing/shift mapping, session-close evaluation order) —
   these were genuine build-blocking ambiguities in the original card (not previously
   specified at all), not contested wording, so no independent verification table was
   needed; they were persisted as proposed.

## Registry / identity verification (independent check, not just relayed)

`framework/registry/magic_numbers.csv` (read from the canonical checkout; not
modified — registry writes are governed-allocator-only) shows all 7 rows for
`ea_id=20078` active, one per `target_symbols` entry in the card:

```
20078,volume-profile-poc-retest-intraday,0,EURUSD.DWX,200780000,2026-09-22,Codex governed allocator,active
20078,volume-profile-poc-retest-intraday,1,GBPUSD.DWX,200780001,2026-09-22,Codex governed allocator,active
20078,volume-profile-poc-retest-intraday,2,USDJPY.DWX,200780002,2026-09-22,Codex governed allocator,active
20078,volume-profile-poc-retest-intraday,3,XAUUSD.DWX,200780003,2026-09-22,Codex governed allocator,active
20078,volume-profile-poc-retest-intraday,4,NDX.DWX,200780004,2026-09-22,Codex governed allocator,active
20078,volume-profile-poc-retest-intraday,5,WS30.DWX,200780005,2026-09-22,Codex governed allocator,active
20078,volume-profile-poc-retest-intraday,6,GDAXI.DWX,200780006,2026-09-22,Codex governed allocator,active
```

Matches the task payload's claim ("all seven card magic rows are allocated and
verified"). No registry write performed by this task (out of scope — governed
allocator only; no collision, no append).

## Action taken on the resume instruction

Per task payload: "Then resume original build task
`751d8eb5-d9de-4cfe-85c6-27468c409078`. Do not create another EA/build task or revive
rejected duplicate 12038." No new task created; duplicate 12038 not touched.
`751d8eb5` moved `BLOCKED -> TODO` via `agent_router.py update-task`, artifact-path
pointing at the amended card, verdict recording that the blocker is resolved and the
amendment is durable. `751d8eb5` remains `decision_bound_agent: codex` — this task did
not execute the build itself (out of lane; build execution belongs to the codex build
lane per the existing decision binding).

## No performance evidence claimed

This review is a card-text/arithmetic fidelity fix, not a backtest or pipeline result.
No trade frequency, PF, or DD claim is made or implied by this change.
