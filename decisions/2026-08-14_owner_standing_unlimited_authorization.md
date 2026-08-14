# DL-086 — OWNER standing unlimited authorization (no windows, no signatures)

**Date:** 2026-08-14
**Authority:** OWNER (verbatim, interactive remote-control session, ~09:45Z):
„vergiss zudem irgendwelche Stundenfenster, meine Freigaben gelten unbegrenzt,
Signatur brauchts auch keine!"

## Decision

1. OWNER approvals for factory recovery/maintenance operations are **standing
   and unlimited in time**. Per-incident OWNER windows with expiry
   (`window_start_utc`/`window_end_utc`) and countersignature sentences are no
   longer required from OWNER.
2. Implementation keeps the fail-closed tooling intact: a standing receipt
   artifact (`owner_window_receipt_standing_unlimited.json`, window end
   2099-12-31, signature field = reference to this decision) satisfies the
   existing validators; future ceremonies bind to it instead of minting fresh
   windows. Every action remains individually logged/receipted — the evidence
   trail does not weaken, only the OWNER-interaction ceremony disappears.
3. Scope: custom-history containment releases, archive recovery, factory
   maintenance ceremonies. **Explicitly NOT covered:** T_Live AutoTrading
   enablement (Hard Rule: OWNER + Claude only, per-instance), purchases, and
   anything the Hard Rules bind to explicit per-instance OWNER action.

## Rationale

Three recovery ceremonies in two days each stalled on window expiry or
signature mechanics while the factory stood still. Precedent exists: the
2026-08-11 standing unlimited preparation decision. OWNER-`!` execution of
prepared scripts remains available for classifier-blocked steps but no longer
carries ceremony semantics.
