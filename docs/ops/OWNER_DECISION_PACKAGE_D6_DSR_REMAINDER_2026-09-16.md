# OWNER DECISION PACKAGE — D6: Q08 DSR remainder (V4 scope extension + §8.5 sub-decision) (2026-09-16)

**Prepared by:** Kimi (interim operator) under the interim OWNER delegation.
**Authority basis:** interim directive outcome-B — "prepare the smallest decision package possible."
**State:** Factory RUNNING. Audit only — **no DB writes, no repairs executed.** Full per-row
evidence: `docs/ops/evidence/2026-09-16_dsr_remainder/AUDIT.md` (+ `audit_rows_raw.json`,
`classification_live.json`).

---

## DECISION 6 (V4) — Extend the V3 Q08 single-configuration repair pattern to the 12 SAME_V3_CLASS rows

**Decision required:** Issue `OWNER-DEC-Q08-CONTEXT-REPAIR-V4-20260916` (citing
`OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916`, parent `…-V2-20260914`) extending the approved
V3 repair pattern — governed card amendment + append-only disposition (supersede) + fresh
Q08 enqueue from the done/PASS Q07 predecessor with current-build binding — to the 12
remainder rows whose defect is **identical** to the 16-card V3 cohort: approved card without
a `qm-dsr-single-configuration` declaration **and** row without recorded build identity.

**Affected scope (exactly 12 rows / 12 EAs — the class-A population):**

| work item | EA | symbol | Q07 predecessor (done/PASS) |
|---|---|---|---|
| f762cbe6-… | QM5_10037 | XAUUSD.DWX | 0bd38739 (09-13) |
| 75af8ef0-… | QM5_10122 | XAUUSD.DWX | d93be636 (09-14) |
| fba34963-… | QM5_10127 | NDX.DWX | bd1534b2 (09-14) |
| 4300c5ad-… | QM5_10134 | XAUUSD.DWX | e48b7bfe (09-14) |
| c297063b-… | QM5_10691 | NDX.DWX | cf197dd4 (09-14) |
| 47bea32e-… | QM5_10947 | NDX.DWX | 49b48658 (09-14) |
| fda2f049-… | QM5_1206 | SP500.DWX | c66474ef (07-29) |
| ba75c59a-… | QM5_12354 | NDX.DWX | d374a221 (09-02) |
| 676b23b9-… | QM5_12358 | XAUUSD.DWX | e4be5458 (09-14) |
| 4aa9b74b-… | QM5_12366 | XAUUSD.DWX | 67d04308 (09-14) |
| 962d1a67-… | QM5_12549 | XAUUSD.DWX | 6fbc8bde (09-14) |
| 235bf9ad-… | QM5_1615 | XAUUSD.DWX | 0b76d4ca (09-14) |

(Full ids in the AUDIT. Per-row facts: card `g0_status=APPROVED` with **no** declaration
block; `mq5/ex5/setfile` sha256 all NULL; EA-wide factory search clean — 0 prior
OPT_/Q12–Q16 rows, so the claim-time `FACTORY_SEARCH_LEDGER_PRECEDES_Q08` check will pass;
window already present, 2017-01-01..2025-12-31; SPEC.md present; setfiles non-empty.)

**Why OWNER authority is required:** card amendments on approved cards are OWNER-only
acts (`g0_status`/approved-card acts per `docs/ops/evidence/2026-09-16_opt_sibling_10911/RECEIPT.md`
stop-line; the interim delegation explicitly does **not** cover them — the 16-card cohort
waited for V3 exactly here). V3's **named scope** covers only its 16 cards; these 12 rows
match the V3 defect pattern exactly but are outside the named list. Extending the named
scope is a scope-extension call, not a mechanical inference (no scope inference was made —
V3 batch execution STOPped on exactly this boundary).

**Evidence (V3 execution receipts as precedent):**
- `docs/ops/evidence/2026-09-16_q08_amend_v3/RECEIPT.md` (batch 1, receipt `d59b2277`) and
  `batch2/RECEIPT.md` — the full amend + disposition + fresh-enqueue pattern, five-proof
  gates, `D1 status: APPLIED (16/16 cards)`.
- `batch2/RECEIPT.md` §3-§5: disposition tool (`session_tools/q08_repair_dispositions_0914.py`)
  + governed `farmctl enqueue-backtest --phase Q08 --from-work-item-id <Q07>
  --expected-current-ex5-sha256 …` — the exact mechanics to copy.
- D1 outcome proof (handoff §"OWNER decisions"): 8/8 batch-1 fresh rows claimable, proofs
  PASS; batch-2 8/8 with dispositions + fresh enqueues; first runs legitimate
  (10287 FAIL_HARD end-to-end with DSR SEALED).

**If APPROVED:** 12 rows become claimable after amend + disposition + fresh enqueue →
**+12 Q08 crisis-gate candidates** (7 XAUUSD crisis-gate-lane, 4 NDX, 1 SP500) — direct
capacity fill on the symbols the book evolution cares about. Two of them (10947, 1206)
additionally carry the independent `RAM_RESERVATION_44GB_NOT_WINNABLE_20260914` hold and
only become *runnable* with a separate 44 GB window release (same class as D3's
`RAM_WINDOW_44GB` ask — not bundled here).

**If DECLINED:** the 12 rows stay parked; the claim window keeps skipping them; the fleet
loses up to 12 crisis-gate candidates until a later decision.

**Risks:** same class as V3/D1 (append-only everywhere; no verdict touched; governed
tooling with dry-run → apply → five proofs). Card-amendment risk is the V3-proven one
(locked-parameter recompute vs live mq5/setfile + spec sha binding). Fresh enqueues are
deduped and hash-pinned. No gate threshold / DSR formula / candidate-universe change.

**Rollback:** append-only dispositions + supersedes edges are the rollback (pattern
established 09-14/09-16): supersede the fresh rows, restore nothing (original bytes
preserved in journals `card_amend_journal.jsonl` + `manifest.json`).

**Kimi recommendation:** `APPROVE` — A-class rows are 12 of the 15 repair-relevant rows
in the population; the pattern is V3-proven end-to-end on the identical defect
(16/16 applied, 8/8 + 8/8 proofs green). Decline cost (12 crisis-gate candidates parked)
far exceeds the contained risk.

**Post-approval commands (mirror D1 batch-2 exactly; staged dry-run first):**
```
# 1) point the amend tool at the 12 cards (constants: DECISION_ID=V4 id, RECEIPT_ID=new)
python tools/strategy_farm/session_tools/q08_single_config_amend_0914.py --dry-run …   # 12 ok expected
python tools/strategy_farm/session_tools/q08_single_config_amend_0914.py --apply …
# 2) dispositions for the 12 staged rows (PLAN = the 12 prefixes; EVID/TASK_ID updated)
python tools/strategy_farm/session_tools/q08_repair_dispositions_0914.py --dry-run …
python tools/strategy_farm/session_tools/q08_repair_dispositions_0914.py --apply …
# 3) fresh enqueue per row from its Q07 predecessor with the current ex5 sha256
python tools/strategy_farm/farmctl.py enqueue-backtest --phase Q08 \
  --from-work-item-id <Q07_id> --expected-current-ex5-sha256 <live sha256> …
# 4) five proofs (a card hashes, b declaration correctness, c precheck flip,
#    d no false-declaration refusal, e wiki health), then governed hold release
python tools/strategy_farm/farmctl.py release-hold --work-item-id <id> \
  --expected-hold-code Q08_DSR_CONTEXT_UNAVAILABLE --release-note "…V4…"   # dry-run first
```
Explicitly **not** in V4 scope (separate dispositions needed, per AUDIT §2): the 3
SPEC-missing rows (12361/12484/1551 — join V4 once SPEC.md exists), the 3 censused-EA rows
(10145×2, 10692 — grouped-cohort or retire), the 3 multi-symbol rows (12350, 10287-XAUUSD,
1230-AUDJPY — second-card vs retire), the 2 ablation rows (10932, 10163 — Weg-2 call), the
8 windowless rows (explicit-date re-enqueue; 3 of them V4-eligible once windowed), the 4
no-card sweep-arm rows (awaiting Weg 2), the 3 superseded-residue rows (hold cleanup only),
11167 (re-amend if revived), 1328 (quarantine disposition).

---

## SUB-DECISION 6b — §8.5 neighborhood-evidence regeneration for the 09-14 pair (QM5_13137)

**Decision required:** Authorize regeneration of the §8.5 neighborhood evidence lineage
for QM5_13137/XAUUSD.DWX and an append-only Q08 rerun of the done-INVALID row
`d02a1128-c6ee-4e4e-ad82-755937a06421` (identity: current ex5/setfile build), or decline
and leave the EA without a completed Q08.

**Affected scope:** QM5_13137 only. (Sibling QM5_11121 of the 09-14 pair resolved
legitimately — economic FAIL_HARD; nothing owed there. The V3 fresh rows are separate and
not part of this sub-decision.)

**Current blocker:** Q08 INVALID —
`8.5_neighborhood: neighborhood_evidence_lineage_invalid:evidence_status_missing_or_invalid`
(aggregate `sub_gates`, empty evidence; artifact `8_5_neighborhood.json` records the same).
The support runner itself completed (baseline VALID, PF=1.96, 117 trades, exit 0,
`artifact_now_exists: true`), but the lineage validator requires the artifact's
`evidence_status == "VALID"` **and** post-run reuse acceptance
(`framework/scripts/q08_davey/aggregate.py:249-257`, `:296-306`); the stale archived
lineage failed reuse (`reuse_check: artifact_missing`) and the gate fail-closed. A plain
rerun without evidence regeneration reproduces the INVALID (deterministic, per
`decisions/2026-07-25_q08_tooling_invalid_is_infra.md` retry-owed-infra class).

**Why OWNER authority is required:** it authorizes work-item mutation (append-only rerun
enqueue) plus targeted evidence regeneration under a done verdict's identity — a
verdict-adjacent act outside standing autonomous authority (no verdict is rewritten; the
INVALID row stays as evidence).

**Evidence:** `docs/ops/evidence/2026-09-16_dsr_remainder/AUDIT.md` §5 (code-level
mechanism + artifact paths); aggregate at
`D:\QM\reports\work_items\d02a1128-c6ee-4e4e-ad82-755937a06421\QM5_13137\Q08\XAUUSD_DWX\aggregate.json`;
handoff post-verdict note (`KIMI_INTERIM_HANDOFF_2026-09-18.md:135`).

**If APPROVED:** regenerate the §8.5 neighborhood evidence under the current build
identity (support runner re-run → artifact with `evidence_status: VALID` + param_source
sha binding) → append-only Q08 rerun (`farmctl enqueue-backtest --append-only-rerun-of
d02a1128-… --expected-current-ex5-sha256 …`) → first §8.5-readiness proof on the new run.
**If DECLINED:** 13137 stays Q08-INVALID; the XAUUSD crisis-gate lane loses one candidate.

**Risks:** bounded — one regeneration + one rerun; the fail-closed gate is the same one
that produced the INVALID, so a failed regeneration simply re-INVALIDs (no verdict harm).

**Rollback:** none needed beyond declining further reruns; all prior evidence is
append-only.

**Kimi recommendation:** `APPROVE` (small, contained, restores one crisis-gate candidate;
the defect is tooling, not economic).

**Post-approval execution:** mechanical (regenerate → verify artifact `evidence_status:
VALID` + lineage → append-only rerun → watch first verdict's §8.5 gate). No further OWNER
action.

---

**Not requested (out of scope / handled elsewhere):** the 38 superseded BUILD_IDENTITY
bucket rows (no repair needed; optional stale-hold cleanup later) · the other B/D subclass
rows enumerated above (each needs its own small decision; the 3 SPEC-missing rows are the
cheapest follow-on) · D1-D5 items already decided.
