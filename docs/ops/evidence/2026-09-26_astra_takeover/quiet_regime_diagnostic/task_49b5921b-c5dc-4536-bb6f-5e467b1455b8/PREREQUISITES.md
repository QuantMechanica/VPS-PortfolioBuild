# Quiet-NDX TRIX causal replay — bounded prerequisite contract

Task `49b5921b-c5dc-4536-bb6f-5e467b1455b8`. This cycle performed read-only
verification only: no implementation, build, EX5, MT5 run, new outcome, or
book-metric claim. `activation_approved=false`; nothing here changes that.
This document is the task's `required_output` via its second branch — "a
precise internally actionable prerequisite list" — rather than a new reviewed
implementation, because the upstream blockers below are unresolved and writing
executable replay code against them would either stall on missing inputs or
risk inventing evidence the protocol explicitly forbids.

## 1. Confirmed resolved / hash-bound (prior work, re-verified this cycle)

- Research protocol accepted with six binding clarifications:
  `PROTOCOL_ACCEPTANCE.md` (task `d75c4d90-e315-4faa-a473-a48d4406db85`).
- Historical input reconciliation: four native reports hash-verified; Q04
  (`InpQMSimCommissionPerLot=5.5`) vs Q05 (`0.0`) input diff identified; exact
  Q04 setfile recovered and hash-bound; Q05 setfile byte identity **not**
  found (bounded negative search, not proof of absence): `INPUT_RECONCILIATION.md`.
- Pure ATR/rank feature component independently reviewed and landed
  synthetic-only (commit `2bf3b90656`, 18 tests, `PASS_QUALIFIED`): no raw
  loader, no price history, no costs, no MQL5 build —
  `feature_preparation/IMPLEMENTATION.json`, `feature_preparation/INTEGRATION_CONTRACT.md`.
- NDX cost/symbol input preparation: hash-sealed `US100.cash` SymbolInfo
  snapshot (read-only IPC, no account action); FTMO "zero commissions on
  indices" primary-source page fetched and hashed; declared 10:1 contract-size
  gap between `US100.cash` (size 1) and the historical `NDX.DWX` registry
  (size 10, derived $10/point/lot) flagged as unreconciled —
  `input_readiness_20260928/FINDINGS.md`.
- **New this cycle**: re-hashed the current canonical EA source,
  `framework/EAs/QM5_10290_cinar-trix/QM5_10290_cinar-trix.mq5`
  (SHA256 `4113a65051a0942f726c2d13191466caa8bfb052ab1ef25069a9b1aeffa83cf0`,
  git blob `aa862415722b351056ead2a5a07849ea954dd61f`). It matches the hash
  cited in `PROTOCOL_ACCEPTANCE.md` §2 exactly — the source has not changed
  since protocol acceptance.
- **New this cycle**: read the source directly and confirmed, by line number,
  the exact causal structure the protocol describes rather than taking it on
  trust:
  - `Strategy_EntrySignal` (line 130) computes the TRIX sign, and if an
    opposite position exists, closes it via
    `QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL)` at line 161; on
    close failure it returns `false` at line 162 **before** any new request
    is built, so a failed close correctly blocks reversal with no retry.
  - The quiet-volatility entry gate (§4 of the protocol) must be inserted
    strictly between line 163 (end of the close-resolution block) and line
    165 (`go_long = (signal_direction > 0)` / request construction) — gating
    only whether a *new* request is built and returned, never the preceding
    close and never `Strategy_ExitSignal` (line 185, currently hardcoded
    `false` — exits are close-on-opposite-signal only, no independent exit
    path exists to accidentally veto).
  - `OnTick` (line 226) only calls `Strategy_EntrySignal` after
    `QM_IsNewBar()` (line 264) gates the whole evaluation to one closed-bar
    event, confirming protocol clarification 5 — `QM_IsNewBar()` is an event
    gate, not itself a data-fidelity proof.

## 2. Outstanding blockers (none resolved, none invented)

1. **Calendar/clock authority.** The feature component has no loader and
   cannot establish session-completeness authority; an independently
   qualified open-session calendar, aligned one-for-one with slots and not
   derived from the same observed price archive, is still missing —
   `feature_preparation/INTEGRATION_CONTRACT.md`.
2. **FTMO normal/stress cost contract.** Indices are commission-free per the
   fetched primary source, but spread, slippage, swap/financing and the
   10:1 contract-size adapter remain unreconciled; "zero commission" is
   explicitly not "zero total cost" — `input_readiness_20260928/FINDINGS.md`.
3. **Fresh-quote margin/spread.** The margin/profit probe on Sept 28 refused
   for lack of a live quote; `margin_initial=0` is not evidence of zero
   margin. Python `SymbolInfo` also supplies no historical calendar —
   `input_readiness_20260928/FINDINGS.md`.
4. **Q05 setfile byte identity.** Unrecovered across four Git revisions and
   the Q05 work-item directory; stays a negative search, not a resolved gap.
5. **Execution-fidelity tolerance.** Protocol clarification 6: "a reference
   to an existing harness tolerance is not a defined tolerance." State
   transitions, fills, costs and trades must be compared explicitly; no such
   hash-bound tolerance contract exists yet for this pair.
6. **Governed build/registry identities.** Both C0 and C1 need new governed
   builds from the current source hash; no verdict or identity inherits from
   history (protocol §2). Neither has been allocated.
7. **Exposure/selection ledger.** `exposure_ledger.json` leaves
   `dsr_trial_count: null` with an explicit note that this receipt does not
   resolve effective-trial accounting. Unchanged by this task.
8. **Paired marginal-book simulation inputs.** Blocked transitively on 1–6;
   no incumbent-alone / +C0 / +C1 comparison can run without them.
9. **Stage B confirmation window.** No genuinely unobserved window has been
   identified or locked in the ledger; only Stage A retrospective
   falsification is currently reachable even once 1–6 clear.

## 3. Ordered next engineering steps (no step skips an earlier one)

1. Authenticate the open-session calendar/clock from a source independent of
   the price archive the feature will consume.
2. Hash-bind the FTMO NDX normal + stress cost contract: reconcile the 10:1
   contract-size adapter, capture a fresh-quote margin/spread sample, and
   record both commission vintages (5.5, 0.0) as provenance only.
3. Define and hash-bind the native/harness execution-fidelity tolerance
   (state transitions, fills, costs, trades — not aggregate PF agreement).
4. Only once 1–3 are hash-bound: implement the causal C0/C1 replay that
   composes the already-reviewed feature component (`quiet_ndx_feature.py`,
   commit `2bf3b90656`) with the gate-insertion point verified in §1 above,
   and route it through independent implementation review before any run
   against real data.
5. Allocate governed build/registry identities for C0 and C1; run Stage A
   retrospective falsification; attempt to lock a genuinely unobserved
   Stage B window if one exists.
6. Paired marginal-book simulation against the frozen incumbent (D2g6)
   roster: `DELTA_P80`, `PAYOUT_EVER_LCB`, and the rest of §7's metric list.

## 4. Non-claims

No strategy card, build, compile, run, P80, DELTA_P80, or book-admission
claim is made or implied by this document. The frozen incumbent roster,
canonical book metrics, and all parent verdicts (QM5_10290 FAIL,
QM5_10614 parked) are unchanged.
