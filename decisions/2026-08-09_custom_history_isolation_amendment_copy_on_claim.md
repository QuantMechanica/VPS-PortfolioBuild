# DECISION AMENDMENT — Variant A archives: copy-on-claim privatization

Date: 2026-08-09
Authority: OWNER (verbatim: "Ja freigegeben", 2026-08-09 ~16:20 local, in
direct reply to Claude's recommendation after the live archive-deletion
findings). Amends: `decisions/2026-08-07_custom_history_isolation_variant_a.md`
(sha 9c9dc230…) inside the countersigned window
`custom_history_variant_a_20260809`.

## Live findings that force the amendment

1. The ratified premise "archive years are read-only for MT5" is false: the
   tester opens `.hcc`/`.tkc` for write unconditionally. The ACL write-deny
   turned that into error 5, and MT5's corrupt-history reaction is DELETE.
   Two runs (T1 XAUUSD Q08 work item `5c3506e0`; T5 build-lane smoke for
   QM5_20202) deleted 117 archive files (XAUUSD 108, XAGUSD 9).
2. The build-lane `run_smoke` selects "free" terminals and bypasses the
   isolation gate entirely (T5 was gate-held yet ran a full session).

Fail-closed behaviour worked: `ARCHIVE_LINK_COUNT_TOO_LOW` held the fleet,
all 216 missing hardlinks were restored from the retained rollback tree
(families verified 11/11 afterwards), containment re-engaged. No data loss;
T_Live/FTMO untouched throughout.

## Amendment (OWNER-approved)

1. **Copy-on-claim privatization**: before dispatching a run, the worker
   replaces the archive hardlinks of the claimed symbol set (host symbol plus
   declared conversion/basket dependencies) on that terminal with
   SHA-verified private copies (temp-copy → sha256 == manifest → atomic
   rename). Idempotent when already private. Disk cost is bounded by the
   actually-tested symbol set (D: free 193 GB).
2. **Gate contract**: an archive file is valid as EITHER a family hardlink
   (link count ≥ family minimum) OR a terminal-private file whose sha256
   equals the manifest row. Everything else remains fail-closed.
3. **ACL**: the archive write-deny for the runner identity is dropped
   (privatized files must be writable-openable by MT5); deletion protection
   moves to the gate contract + rollback tree.
4. **Smoke-lane integration**: `run_smoke` terminal selection must respect
   the isolation gate/ramp state (gate check + reservation before any
   terminal launch).

Rollback tree retention is unchanged. The ramp/soak plan of the ratified
decision continues after the amendment lands, is reviewed by Claude, and the
per-claim audits pass again.
