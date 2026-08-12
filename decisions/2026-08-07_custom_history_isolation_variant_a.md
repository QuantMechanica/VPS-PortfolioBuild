# DECISION — Custom-history isolation: Variant A, Sunday 2026-08-09

Date: 2026-08-07
Authority: OWNER (verbatim: "Variante A, Sonntag, passt", 2026-08-07 morning)
Prepared/verified by: Claude (review APPROVED fe1d5968) · Design: Codex (4e8cd38a6)
Decision package: `docs/ops/evidence/2026-08-07_custom_history_isolation_owner_decision.md`
Root-cause evidence: `docs/ops/evidence/2026-08-06_error32_history_sharing_violation_class.md`

## Decision

Approve **Variant A** — a physical `Bases\Custom` working tree per runner
terminal T1–T10: private writable current-year (`2026`) `.hcc`/`.tkc` plus all
`.hc`/`.dat`/unclassified state per terminal; archive years 2017–2025 provided
as content-verified read-only hardlinks from a signed immutable archive
manifest. Measured incremental disk floor 18.153 GiB (fits; ~68 GiB projected
free). Variant D (global Custom-history lease) is authorized ONLY as
containment during migration and as rollback mode.

Rejected: full physical copies (~389 GiB, does not fit), any real-tick/history
retention reduction (violates Model-4/evidence contracts).

## Window

Sunday **2026-08-09**, market closed. Factory quiesce per runbook (stop claims,
drain active tests — never interrupt a running backtest), staged cutover with
dual `PASS_ISOLATED` audits, ramp 1→2→5→10 slots, then ≥24 h / ≥500-run soak
before containment removal. Rollback tree retained. **T_Live and FTMO are out
of scope and must not be touched.**

Bundled into the same quiesced window:
- Factory ON ceremony re-assert/remint of the decision-bound file SHAs
  (farmctl/terminal_worker commits 1d1e16e58, 590362fa0, fc9110780).
- Full worker-fleet recycle (clears any remaining pre-fix in-memory modules).

## Conditions binding the implementation (from review verdict fe1d5968)

1. Lease-release sequencing must be made explicit: global lease released after
   the dual cutover audits pass, BEFORE ramp step 1; automatic re-engage on any
   stop condition. (Soak occupancy ≥80% is impossible under an active lease.)
2. Clarify/name the exact protected-root set (the design doc's "T_Live/T5"
   wording).
3. Startup fail-closed gate (`mt5_history_isolation.py` + file-ID and
   archive-immutability checks) wired into the governed worker claim boundary.
4. OWNER signs the concrete window time, terminal list, archive manifest hash,
   and rollback authorization before the first filesystem mutation (manifest
   doc to be prepared by Claude, countersigned Sunday morning).

## Why

Chronic fleet-wide ERROR_SHARING_VIOLATION [32] on the shared mutable
T1-junctioned Custom store is the proven mechanism behind the
"cold-cache/INFRA_FAIL" latency class (≈6,000 hits/day, fatal at load peaks;
direct handle attribution T8-holds/T6-dies). Per-terminal isolation removes
the collision surface; hardlinked immutable archive years avoid the disk-cost
of full duplication without touching retention.
