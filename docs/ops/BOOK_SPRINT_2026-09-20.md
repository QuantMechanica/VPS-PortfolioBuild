# Book sprint — DXZ book v2 + FTMO book v2 by Sunday 2026-09-20 12:00 local (10:00Z)

OWNER 2026-09-14 ~20:0xZ: "Unterstütz die Codex Lane mit Sonnet! Ziel ist bis Sonntag Mittag ein neues Darwinexzero und
ein neues FTMO Buch. Alles was du dafür brauchst musst du halt noch machen bis dahin! Überprüfe täglich deinen Fortschritt!"
Orchestrator: Claude (Fable) with the Claude headless lane on Sonnet; Codex stays budget-paced (73 % vs line, reset Fri
2026-09-19 08:29Z). Daily check: written into this file at the 07:21Z watch, reported to the OWNER.

## 0 · The one gate both books share

Both builders and the deploy tool call `risk_freeze.assert_live_book_mutation_allowed` — the LIVE_RISK_FREEZE (ACTIVE
since 2026-08-31) refuses even minting a manifest (verified 2026-09-14 20:2xZ: `build_book_ftmo.py --order-dir decisions`
→ `LIVE_RISK_FREEZE_BLOCKED`). Lift rule (verbatim, `risk_freeze.py`): *all three conditions met AND an explicit written
OWNER lift; no AI seat lifts it, none by inference.* There is no `lift` subcommand — the lift is the OWNER's written
sentence transcribed into `live_risk_freeze.json` (status LIFTED, `lift_authority`, `lifted_at_utc`), plus the signed
deployment pointer (SP-A1/A2).

| Condition | State 2026-09-14 | Path to green |
|---|---|---|
| 1 SP-A1/A2 deploy pointer / identity | **satisfied by attestation** (receipt 424fb9d6, consumer OWNER_ATTESTED_CURRENT_IDENTITY) | signed pointer at the ceremony (`generate_live_deployment_pointer.py --signed --approved-by OWNER`) |
| 2 NEWS-CONTRACT-V2 | PARTIAL: (1) §6 known_at_utc missing, (2) §8 MQL5↔Python DST sweep + 7.30 % regression re-run missing, (3) 11 Q10_NEWS rows REVIEW_REQUIRED, (4) flag QM_NEWS_IMPACT_MAPPING_V2 not activated | Sonnet tickets 01870d4c (§6) and 53bf70a3 (§8) by Wed; (3) rerun or documented as accepted residue; (4) OWNER go + worker reload Thu |
| 3 GOVERNOR-HARDENING | points 1–3 ratified (policy f2baf21a, activation 5ab3b819, order file); enforce switch deferred to the chart attach | enforce inside the ceremony window (task 9e5db1e9 record) |

Fallback if condition 2 cannot be closed by Thursday evening: OWNER decision card "Freeze-Bedingung 2 für den Cutover
als erfüllt werten, Restpunkte (x) als Nacharbeit" — the OWNER's written lift can carry that scope explicitly.

## 1 · DXZ book v2 (28 sleeves @ 11.0 %, staging `C:/QM/deploy/DXZ_V2_20260913/`)

Ready: roster + builder APPLY_RECOMMENDED, presets/binaries/copy plan, deploy manifest DRAFT, Q16 checklist rev 3,
repair_v2 for 12969 (41470) DEPLOYABLE_AT_CUTOVER, identity rule ACTIVE, attestation done.

| # | Item | Owner | Due | Status |
|---|---|---|---|---|
| D1 | Freeze condition 2 §6/§8 (tickets 01870d4c, 53bf70a3) + 11 REVIEW_REQUIRED rows | Sonnet lane / Claude | Wed 09-17 | open |
| D2 | Q16 checks 6 (commission/swap evidence) and 7 (DST artifact), no invented values (ticket 8d8a23e1) | Sonnet lane / Claude | Wed 09-17 | open |
| D3 | Q16 check 10 magic embedding 9641/WS30 (INIT log after attach) and check 9 routing XAGUSD/WS30 (OWNER Market Watch) | Claude / **OWNER** | ceremony | open |
| D4 | Governed lift transcription tool + signed pointer command, ceremony ANLEITUNG final (one page, OWNER acts only) | Claude | Fri 09-18 | open |
| D5 | OWNER written lift sentence + flag go (V2) + Market Watch XAGUSD/WS30 | **OWNER** | Sat 09-19 | open |
| D6 | Ceremony: stage presets → deploy copy-plan → Claude verification → chart attach → governor enforce → **AutoTrading (OWNER)** | Claude + **OWNER** | Sun 09-20 09:00–11:00 local | open |
| D7 | 12778/13117 (NOT_EQUIVALENT rebuilds) stay dark no-ops in v2; own chains continue | — | after | accepted |

## 2 · FTMO book v2 (demo account 1514536732, FTMO-Demo, governor QM5_13206 M13)

Honest state: the strict FTMO qualification gate admits **0 of 16** pairs (2026-09-09 planner: every pair carries
INCLUDE_CLOSURE_NOT_CURRENT, TARGET_FTMO_CALENDAR_SCOPE_AND_ROW_RELEASE_REQUIRED, PROSPECTIVE_WINDOWS_NOT_SEALED,
COST_AND_EXECUTION_ACCEPTANCE_REQUIRED; 12 need FTMO-scope Q10 evidence = 16 native runs each). The FTMO builder's last
dry-run (2026-08-12) was BAR_NOT_MET with 0 sleeves; today it is freeze-blocked before the bar. **Reading of the order:**
the deliverable by Sunday is the FTMO **demo** book v2 (free trial, governor M13) built with the same ceremony rules,
not a paid challenge (external budget 0, `FTMO_ACCELERATION_2026-09-09.md`). If the OWNER means a challenge purchase,
that is a separate decision the sprint does not make.

| # | Item | Owner | Due | Status |
|---|---|---|---|---|
| F1 | OWNER order file `decisions/2026-09-14_owner_book_order_ftmo.md` (chat order transcribed) | done 20:2xZ | — | **done** |
| F2 | FTMO inputs: versioned cost/swap snapshot from the 2026-09-06 native specs, FUND_SCORE coverage of the 26 pairs, builder command file (ticket ac25ebea) | Sonnet lane / Claude | Wed 09-17 | open |
| F3 | Builder dry-run once the freeze is lifted (or with an OWNER-scoped exception for analysis) → bar status; if BAR_NOT_MET: exact missing evidence per pair and the OWNER choice (demo book from the bar-passing subset, or none) | Claude | Thu 09-18 | open |
| F4 | FTMO demo deployment package v2 (presets FTMO env, symbol mapping .DWX→FTMO names, governor policy unchanged, copy plan) + ANLEITUNG | Claude | Fri 09-18 | open |
| F5 | OWNER: attach + AutoTrading on the FTMO demo terminal in the Sunday window (after DXZ) | **OWNER** | Sun 09-20 | open |

## 3 · Sonnet lane load (Claude headless, CLAUDE_HEADLESS_MODEL = sonnet)

Re-routed from Codex 2026-09-14 20:2xZ: 79d1c0fa (evidence loss P0), 53d15c01 (OOS-2026 FTMO campaign), 42ff3c7a (health
hygiene), 70a31d19 (13013 Tier-A), 11eff123 (winsweep compile path), 7d9dd3b5 (Q08 sweep-arm context, way 1). New: 01870d4c
(§6), 53bf70a3 (§8), 8d8a23e1 (Q16 6/7), ac25ebea (FTMO inputs). Codex keeps the rest (56 non-build TODO) at the
budget line. The orchestrator reviews every REVIEW row within the hour of its watch.

## 4 · Daily check protocol

At the 07:21Z watch: (a) update the status columns above, (b) list what moved to REVIEW/APPROVED, (c) name the
day's single most important blocker and who owns it, (d) report to the OWNER in ≤ 6 lines. Sunday 08:00Z: go/no-go per
book with the exact remaining OWNER acts.

## Daily log

- **2026-09-14 (Mon, 20:4xZ)** — sprint opened. Shared gate identified (risk freeze). DXZ: conditions 1 and 3 in
  reach, condition 2 has four open items → two Sonnet tickets. FTMO: order file minted; builder freeze-blocked; strict
  gate 0/16 → demo-book reading of the order, inputs ticket. Codex tickets re-routed to Sonnet (6) + 4 new sprint tickets.
- **2026-09-14 (Mon, 20:5xZ)** — OWNER lift ("Freifahrtsschein"): freeze LIFTED (transcribed, condition 2 carried as
  Nacharbeit), signed pointer for the current identity, DXZ v2 builder APPLY_RECOMMENDED with manifest written, staging
  dry-run clean (24 re-weights + 4 burn-in presets), FTMO builder BAR_NOT_MET (fund scores 0.05–0.09 vs floor 1.0) →
  demo-book path. D4 moves to "profile V3 + reseal + controlled restart" tooling (Tue/Wed). AutoTrading stays OWNER-only.
