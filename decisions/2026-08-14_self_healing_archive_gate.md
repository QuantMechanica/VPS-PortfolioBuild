# DL-085 — Self-healing archive gate (repair-first, containment on donor loss)

**Date:** 2026-08-14
**Authority:** OWNER (ratified interactively in the remote-control session, 14.08. ~10:00Z,
option "Ja, ratifiziert" on the explicit gate-semantics question)
**Context evidence:** `docs/ops/evidence/2026-08-14_claude_archive_eater_forensics.md`
(error-32 audit-vs-MT5 collision class; USN journal absent on D:)

## Decision

The Variant-A custom-history dispatch gate changes its failure response for
manifest archive gaps:

1. **Repair-first:** when the fleet inventory finds a missing manifest-bound
   archive file (`MANIFEST_ARCHIVE_FILE_MISSING` / `TERMINAL_MANIFEST_INCOMPLETE`),
   the gate attempts an automatic repair before failing closed.
2. **Verified-master source:** repairs copy from a standalone MASTER archive
   tree (`D:\QM\archive\Custom_master`, own inodes, outside every MT5 terminal
   directory, never opened by any MT5 process — reads from it cannot collide
   with running testers). Every repair copy is sha256-verified against the
   owner-approved manifest before the atomic move into place. The same master
   becomes the READ SOURCE for copy-on-claim privatization, so privatization
   no longer data-opens the cross-terminal shared family inodes (the proven
   error-32 collision vector).
3. **Receipts:** every repair appends a JSON receipt (UTC time, terminal,
   relative path, sha256, size) to
   `D:\QM\strategy_farm\state\custom_history_repairs.jsonl`. Health surfaces a
   repair-rate counter with WARN/FAIL thresholds.
4. **Containment remains** for real integrity loss: master missing or
   sha-mismatched for a needed file → fail-closed exactly as before
   (automatic_stop_condition).

Accompanying (same ratification): observation is decoupled from operation —
audits must not data-open files of terminals that may have running MT5
processes (stat-only identity via metadata access); full-hash audits require
factory quiescence (FACTORY_OFF); the static always-true ACL receipt stub is
replaced by an honest live sample probe (WARN-level until identity separation
lands).

## Rationale

Proven mechanism (14.08.): audit data-opens collided with exclusive MT5 opens
→ MT5 error 32 → MT5 discards custom-symbol year files → fleet-wide
containment. Three incidents in 5 days (08-10 class, 08-13 T8, 08-14 waves 1+2).
Hardlink repair is instant, copy-free, and keeps the family topology (reduces
private-inode hash load). Fail-closed stays for genuine donor loss, preserving
the evidence guarantee ("evidence over claims").

## Follow-up (not part of this decision)

Identity separation (MT5 under a restricted account, deny-delete on archive
years) as the structural guarantee — Codex project. USN journal creation on D:.
