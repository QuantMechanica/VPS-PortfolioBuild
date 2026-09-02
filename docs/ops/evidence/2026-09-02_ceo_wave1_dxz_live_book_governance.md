# D4 — DXZ Live-Book Governance & the 2026-09-06 Probation Review

Auditor dimension D4 (replaces the failed run). Read-only; no T_Live write, no toggle, no sign, no DB write.
All claims file/DB-evidenced. 2026-09-02.

Companion deliverable: **`wave1/mnt036_delta_2026-09-02.md`** (the refreshed MNT-036 probation package with the
decision matrix). This report covers (2) the risk freeze, (3) the DXZ rules research, (4) the 10440/KS gap, and the
ranked DXZ actions.

---

## Executive summary

- The **three probation sleeves are the book's best-behaved members**, not its problem: 1556/XAU **+149.67**,
  10706/GBP **+394.78**, 13128/NDX **0.00** (flat) realized since book go-live 2026-07-19. Recommendations:
  **CONTINUE 1556 (no scale, one Q07 gap-closer), CONTINUE 10706, REQUALIFY-or-REMOVE 13128.**
- The book's realized **−2,227 since 07-19** is **~76% an untagged magic-0 position problem (−1,700)**, not modeled-
  sleeve edge failure. Governed sleeves net ≈ −527. This reframes the wider audit's "edge is dead" reading.
- **Risk freeze is correctly ACTIVE and blocks all three lift conditions.** The binding one is SP-A1/A2: the
  `live_deployment_pointer.json` is **unsigned** (`signed:false`, `approved_by:null`). Lifting requires an **OWNER**
  signature over an approval-evidence file — no AI seat can mint it. I prepared the exact unsigned dry-run command.
- **10440/NDX is the sharpest live-book defect**: live and trading on a **Q10 FAIL** (no PASS exists) with its
  **kill-switch unarmed** (the 23/24 KS gap). Its baseline literally cannot be built from Q10 evidence because there is
  none. OWNER decision: remove or re-gate.
- **Darwinex Zero economics (researched):** trader keeps **15% of profits** on allocated capital; **$35–50/mo** sub;
  DarwinIA SILVER needs a **rating ≥ 75** (22% current-month + 67% trailing-5-month return + 11% 6-mo max-DD), GOLD
  needs an **8-month track record**. Crucially, **adding/removing strategies does NOT reset the DARWIN track record** —
  the account's track record is continuous and de-listed systems stay visible. The book stands at **rating ≪ 75**
  today (flat/negative trailing return, 2.64% DD, ~4.3-month track record → no bonus tier, no allocation).

---

## (2) Risk freeze — lift conditions and exactly what each needs

Source: `D:/QM/reports/state/live_risk_freeze.json` (status **ACTIVE**, armed 2026-08-31T05:12Z by claude-orchestrator,
decision OWNER-DEC-RISK-FREEZE). Freezes: per-sleeve RISK_PERCENT, the sleeve roster (no add/remove), deployed preset
bytes + bound binaries, all new live promotions. Does **not** freeze backtests, gate work, builds, or read-only
diagnosis.

**Lift rule (verbatim):** "All three conditions met AND an explicit written OWNER lift. No AI seat lifts this freeze,
and no seat lifts it by inference from a condition merely being satisfied."

| # | Lift condition | Status | What is needed (files / signatures) |
|---|---|---|---|
| **SP-A1/A2** | `live_deployment_pointer.json` **signed** and consumers read authenticated instead of UNKNOWN | **BLOCKED** | (a) An **OWNER-signed** pointer: run the generator with `--signed --approval-evidence <decisions/*.md>` — but `signed=true` is an **OWNER/ROT action**, not an AI seat's (help text + T_Live Hard Rule). (b) The approval-evidence file must be a dated, written OWNER approval record. (c) `morning_brief.py` / `verify_live_deployment_contract.py` then read AUTHENTICATED. The 10-preset repair provenance is already archive/receipt-verified (task 58b96908); only the signature + consumer rollout remain. |
| **NEWS-CONTRACT-V2** | News-impact taxonomy implemented under `qm.news_impact_mapping.v1` | **PARTIAL** | Router task 84c988e6; OWNER half decided 2026-08-22 (clean canonical). Gated on Q09 rerun completion. Frontier work, not a live-book write. |
| **GOVERNOR-HARDENING** | Account/portfolio governor hardened **and actually enforcing** | **PARTIAL** | SP-C1 approved + dry-run-proven at commit 593c9ddca, but the **v2 monitor deploy + action adapter are OWNER/ROT-gated and not live**. This is the atomic account-wide pre-trade risk enforcement — same gap flagged as `runtime_integration=NOT_IMPLEMENTED` for FTMO. |

**Book baseline in the freeze file:** `ok:true`, 24 sleeves, total RISK_PERCENT 9.7499, roster_sha256 a98bfdeb…,
21 distinct binaries.

**Unsigned dry-run pointer — prepared, NOT executed (no sign, no T_Live write).**
The generator computes evidentiary fields fresh from disk; unsigned/GELB mode is allowed for an AI seat. The exact
command (values taken from the existing pointer's evidence-backed fields) is:

```
python tools/strategy_farm/generate_live_deployment_pointer.py \
  --manifest "D:/QM/reports/portfolio/portfolio_manifest_live_24sleeve_20260724.json" \
  --environment "T_Live/DXZ" \
  --expected-account 4000090541 \
  --expected-server "Darwinex-Live" \
  --expected-phase "DXZ_LIVE" \
  --deployment-epoch-utc "2026-07-24T06:42:00+00:00" \
  --written-at-utc "<now-iso>" \
  --dry-run --out "<scratch>/live_deployment_pointer_DRYRUN.json"
```

This regenerates the pointer with `signed:false` and prints the fingerprints for OWNER to inspect before signing.
**Signing** = add `--signed --approval-evidence decisions/2026-07-24_owner_approvals_audit_package.md` (or a fresh
dated approval) and is **OWNER/ROT only**. Current pointer state: `signed:false`, `approved_by:null`,
`approval_evidence:null`, `manifest_declared_approved_by` = the 2026-07-24 chat countersign (manifest was approved; the
runtime pointer was never signed).

**Assessment:** the freeze is well-constructed and the blocker is genuinely an OWNER action, not an AI oversight. The
one thing an AI seat *can* do this week is produce the unsigned dry-run + the provenance vorlage so OWNER's signing step
is a 2-minute review. Everything else on the lift list is either frontier gate work (NEWS-v2) or an OWNER/ROT deploy
(GOVERNOR v2).

---

## (3) Darwinex Zero rules — researched, with sources, and where this book stands

**D-Score / DarwinIA rating (SILVER)** — three weighted inputs:
- **22%** current calendar-month return
- **67%** cumulative last-5-months (+ current month) return  ← dominant term; "most relevant metric"
- **11%** maximum drawdown over the current + preceding 5 calendar months

**Track-record bonuses:** +1 point (6–12 mo), +2 (12–18 mo), +3 (>18 mo).
**Allocation threshold:** rating **≥ 75 guarantees** a SILVER allocation each month; higher rank → larger allocation.
**DarwinIA GOLD:** identical rating formula, **8-month minimum track record**, allocation by ranking, up to **€500k**.
**Scale of the programme (Apr 2026):** SILVER €48.55M across 1,398 DARWINs; GOLD €9.68M across 140.

**Fees / split:** monthly subscription **$35–$50** (3-yr plan ≈ $35/mo for a 100k account). Trader keeps **15%** of the
profit generated on allocated investor capital (a management/performance fee, applied only after DarwinIA allocates
external capital). No per-challenge fee model like FTMO.

**Does roster expansion (adding/removing EAs) reset or hurt the track record?** — **NO reset.** Darwinex treats
transparency as non-negotiable: **de-listed/changed systems keep appearing in the track record**; the DARWIN is the
*account's* aggregate index, distinct from any one underlying strategy. So adding sleeves does **not** restart a clock.
It *does* change the forward return/DD series (and can raise investor **divergence** — Darwinex warns if monthly
divergence exceeds −0.2%/mo — and re-target **VaR**, which floats 3.25%–6.5% off a 6-month look-back). **Net answer to
the audit's load-bearing open question: broadening the book now does not cost track-record length; it only changes the
return series the D-Score reads going forward.** This *removes* the main stated risk against an interim book expansion —
but it also means the negative/untagged drags must be cleaned first, because they will sit in the 67%-weighted
trailing-5-month term.

**Where this book stands today (computed):**
- Return: account ~flat-to-negative on trailing return; realized **−2,227 since 07-19** (DD-guard DD **2.64%** off HWM
  101,871.44, breached=false; equity ~99,177 / balance 99,074).
- Track record: first deal **2026-04-24** → ≈ **4.3 months** as of 09-02 → **below** the 6-month (+1) tier (reached
  ~2026-10-24) and the 8-month GOLD minimum (~2026-12-24).
- **Rating estimate: well below 75 → no DarwinIA allocation now.** The 67%-weighted trailing-return term is the lever;
  it turns positive only if the negative sleeves (11708, 11132, 10939, 10513, 1567) and the **−1,700 untagged magic-0**
  losses stop dragging the monthly series. This is a direct argument for *pruning*, not just *continuing*, at 09-06.

Sources:
- DarwinIA Rating / D-Score components & threshold: https://darwinexzero.document360.io/docs/rating
- DarwinIA SILVER doc: https://darwinexzero.document360.io/docs/darwinia-silver
- DarwinIA overview: https://help.darwinex.com/what-is-darwinia
- Fees / 15% split / subscription: https://www.luxalgo.com/prop-firms/darwinex-zero/ and https://propfirm201.com/firms/darwinex-zero
- Track-record transparency on de-listing: https://help.darwinex.com/how-to-delete-a-darwin and https://help.darwinex.com/darwin-vs-its-underlying-trading-strategy
- Divergence / VaR engine: https://help.darwinex.com/asset-manager-divergence and https://help.darwinex.com/risk-manager

*Caveat: figures are from Darwinex public docs + 2026 third-party reviews (US-only search). Confirm the exact current
rating threshold and GOLD track-record minimum against the trader's own Darwinex Zero dashboard before acting on
allocation timing — third-party guides can lag doc updates.*

---

## (4) 10440/NDX kill-switch gap and KS 23/24 — what is needed (no live action)

Source: `live_book_pulse.json` `kill_switch_baselines`: `loaded_ok=23/24; missing_files=["10440|NDX"]; dormant=0;
hash_mismatches=0`. Package Nachtrag §4 (`2026-08-21_probation_package_mnt036.md`).

- **The 23/24 gap is exactly 10440/NDX.** All 23 other sleeves (incl. the 3 probation sleeves) have baselines loaded.
- **Root cause:** MNT-001's OWNER-approved rule generates the KS baseline **from the Q10 evidence**. 10440/NDX has
  **no passing Q10** — it carries a **Q10 FAIL (2026-07-25)**, plus Q08 FAIL_HARD/FAIL_SOFT and Q05 INFRA_FAIL ×34. The
  baseline task `f421b62a` is therefore **not executable as written** (there is no PASS to derive from). This is an
  honest gap, not a missed chore.
- **Live exposure:** 10440/NDX **is trading** (magic 104400003: **+136.11 net**, 3 round-trips, 4 entry-days since
  07-19) on a **failed closing verdict** with **no kill-switch armed**. It is in the signed 24-sleeve manifest
  (slot 15, RISK_PERCENT 0.0577, weight 1.0).
- **What is needed (OWNER decisions, no AI live action):**
  1. **OWNER dispositions 10440/NDX** — REMOVE from roster, or authorize a governed **re-gate** (fresh Q05→Q10) to
     produce a passing Q10 the baseline can derive from. A live sleeve on a Q10 FAIL is an OWNER question, not a Claude
     decision (ROT: live account + candidate pool).
  2. **Until then**, the KS gap stays 23/24 by design — do **not** synthesize a baseline from non-Q10 data (that would
     fabricate the protection anchor).
  3. Because this touches the **roster**, it is currently **frozen** by live_risk_freeze — so it rides the same OWNER
     sitting as the pointer signature and the MNT-036 dispositions (one live-book decision session).

---

## The 3 highest-leverage DXZ actions (ranked)

**#1 — Explain and stop the −1,700 untagged magic-0 live losses (GREEN, read-only run-down; then OWNER).**
This is 76% of the book's realized loss and it sits in the 67%-weighted D-Score term. Two un-tagged live positions
(1.00-lot NDX −1,536.75 on 07-27; 0.43-lot EURUSD −260.77 on 07-24) belong to **no** governed sleeve. Run down whether
it is a manual trade, an unlabeled EA, or a magic-strip bug in the deploy; if it is a rogue/unlabeled trader on the live
account, that is a bigger governance problem than any sleeve verdict. **Owner:** claude-headless (read-only forensic on
the deal stream + T_Live journals) → OWNER for any live remediation. **Effort:** 2–3h. **Zone:** GREEN (diagnosis).

**#2 — Deliver MNT-036 refresh + the OWNER live-book decision session for 09-06 (GREEN prep → OWNER decide).**
Package delta is written (`wave1/mnt036_delta_2026-09-02.md`) with the pre-ratified matrix. Bundle the 09-06 sitting to
cover, in one shot: (a) 3-sleeve dispositions (CONTINUE 1556 no-scale, CONTINUE 10706, REQUALIFY/REMOVE 13128);
(b) 10440/NDX remove-or-re-gate; (c) sign the unsigned deployment pointer over an approval-evidence file (lifts freeze
SP-A1/A2 and clears the live_book_pulse WARN); (d) note NEWS-v2/GOVERNOR-v2 still gate a full lift. **Owner:**
claude-interactive prep → OWNER sign. **Effort:** 2h prep. **Zone:** GREEN prep / ROT decisions.

**#3 — Prune the negative & untested drags before the D-Score's 5-month window matters (OWNER, ROT — roster).**
The DarwinIA rating is 67%-weighted on trailing-5-month return and roster changes **do not reset the track record**
(researched) — so the negative sleeves (11708 −531, 11132 −361, 10939 −265, 10513 −231, 1567 −196) and untested 13128
can be pruned/fixed now at **zero track-record cost**, and the account reaches the +1 bonus tier ~2026-10-24. This is the
single structural lever that moves the book toward the rating-75 allocation gate. Requires OWNER (roster is ROT and
currently frozen). **Owner:** OWNER decision on a claude-prepared REDUCE/REMOVE vorlage. **Effort:** 3h prep. **Zone:** ROT.

---

## Evidence index
- `D:/QM/reports/state/live_risk_freeze.json` — freeze ACTIVE, 3 lift conditions, baseline.
- `D:/QM/reports/state/live_deployment_pointer.json` — signed:false, approved_by:null, 24-sleeve fingerprint.
- `D:/QM/reports/state/live_book_dd_guard_state.json` — DD 2.6449%, HWM 101,871.44, equity 99,177, breached:false, 2026-09-02T08:15Z.
- `D:/QM/reports/state/live_book_pulse.json` — verdict ALARM (26× WARN), KS 23/24 missing 10440|NDX, deploy-pointer reconciliation.
- `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/journal/live_deals_normalized.csv` — 210 deals; per-magic P&L since 07-19 computed inline.
- `docs/ops/evidence/2026-08-21_probation_package_mnt036.md` — identity/gate/seed evidence (carried forward).
- `docs/ops/evidence/2026-08-22_sp_e5_probation_review_matrix.md` — SP-E5 signable template (P&L cells now filled by the delta).
- `docs/ops/evidence/2026-08-22_qm5_13128_missed_fomc_root_cause.md` — 13128 missed-FOMC defect.
- `tools/strategy_farm/generate_live_deployment_pointer.py --help` — unsigned/signed contract (AI = unsigned only).
- DXZ rules: sources listed in §(3).
