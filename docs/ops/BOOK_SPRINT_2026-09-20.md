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
| D1 | Freeze condition 2 §6/§8 (tickets 01870d4c, 53bf70a3) + 11 REVIEW_REQUIRED rows | Sonnet lane / Claude | Wed 09-17 | §6 + §8 **done** (5b3481a462, 29a47ac35f, approved 21:3xZ); residue: 11 REVIEW_REQUIRED rows + flag activation (carried by the OWNER lift) |
| D2 | Q16 checks 6 (commission/swap evidence) and 7 (DST artifact), no invented values (ticket 8d8a23e1) | Sonnet lane / Claude | Wed 09-17 | **done** (81cd1527b1): check 7 GREEN, check 6 GREEN for 4 + class-proxy 2, 1537/XAGUSD stays OPEN (no deal history) |
| D3 | Q16 check 9 routing XAGUSD/WS30: **OWNER adds both symbols to the T_Live Market Watch on Sunday before the ceremony** (OWNER 09-15: "Market Watch mache ich Sonntag"); check 10 magic embedding 9641/WS30 = INIT log after the profile attach (Claude) | **OWNER** (Market Watch) / Claude (check 10) | Sun 09-20 pre-ceremony | open, sequence fixed 09-15 |
| D4 | Profile V3 builder + reseal + controlled restart plan | Claude | Wed 09-17 | **done 09-15 08:0xZ**: `build_tlive_book_profile.py` (e88385624e) built + verified `DarwinexZero_Book2_LiveOps` (29 charts: 23 re-weighted, 41470 replaces 12969, 4 new burn-in, monitor; cutover risk 9.8013 %), 24 re-weighted presets staged (existing_staging_verification.json), `T_Live_ON` resumes via recovery pointer (9977ae7c2c), ceremony `tlive_book_cutover.py plan/apply/rollback` (63b5830b53) with **preflight all green 08:01Z** (34 copy items, freeze lifted, one T_Live process, governor artifacts bound) |
| D5 | OWNER written lift **done 09-14** (Freifahrtsschein); flag go (V2) carried by the lift; **09-15 OWNER confirmation** (`decisions/2026-09-15_owner_freifahrtsschein_scope_1_to_3.md`): manifest v2 rev 3 approved (check 3), 11.0 % risk step confirmed, monitor attach inside the ceremony covered | — | — | **done** |
| D6 | Ceremony (autonomous per OWNER 09-14/09-15), fixed sequence: (0) OWNER Market Watch XAGUSD/WS30 → (1) stage presets --apply → (2) deploy copy-plan → (3) profile V3 (28 charts + monitor-v2) + reseal → (4) controlled T_Live restart → (5) Claude verification (SHA256, magics, ENV/risk mode, calendar) = `claude_verification_signature` → (6) governor enforce; AutoTrading stays as the OWNER set it (Hard Rule). Symbols missing in Market Watch at 09:00 local → their charts are skipped, the rest cuts over | Claude | Sun 09-20 09:00–11:00 local | open |
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
| F2 | FTMO inputs (ticket ac25ebea) | Sonnet lane / Claude | Wed 09-17 | **done** (b70adc6525): cost snapshot v2 (5/10 symbols covered, 5 uncovered listed), FUND_SCORE all 26 pairs far below floor 1.0 → strict Q11_FTMO book not reachable this week |
| F3 | Builder dry-run **done 09-14 20:3xZ**: BAR_NOT_MET (authoritative artifact: `D:/QM/reports/portfolio/book_ftmo_2026-09-14/` dry-run, fund scores below floor 1.0, 0 of 16 pairs) → **content decision 09-15 (orchestrator, OWNER may veto):** FTMO demo book v2 = the DXZ v2 roster (same 28 sleeves, same per-sleeve risk policy) on FTMO broker symbol names, deployed on the FTMO **demo** terminal under the M13 governor as a burn-in/observation book; NO FTMO qualification is claimed for any pair, the strict Q11_FTMO bar and its verdicts stay untouched (no gate change, no admission under the floor) | Claude | — | **done (decision recorded)** |
| F4 | FTMO demo deployment package v2: presets FTMO env from the DXZ v2 sleeves (symbol mapping .DWX→FTMO names via the registry matrix, RISK_PERCENT per governor policy, ENV=live, native calendar), copy plan, verification list + ANLEITUNG; package labelled DEMO-BURN-IN, no qualification claim | Claude | Fri 09-18 | open |
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
- **2026-09-14 (Mon, 23:4xZ)** — DEFECT in the exclusive lane (e246cc0dab): the pre-drain for the 44 GB SP500 row f15ac955
  re-opened on every claim pass (`drain_predrain_open` churn, tracker waited 77,608 s, opened_epoch reset each time, so the
  240-min bound never expired) and refused NEW long-run claims for ~4 h during the class-A Q08 reruns. Mitigation now:
  all >= 40 GB pending rows parked under EXCLUSIVE_LANE_DEFERRED_BOOK_SPRINT_20260914 (6 SP500 Q04 + f15ac955 Q10_NEWS +
  2 heavy FX8 baskets); churn stopped 23:27Z. Fix for Tue: pre-drain bound to its row (abandon only when the row is no
  longer pending), original opened_epoch kept, pre_drain preserved through `_drain_abandon`, scan prefers the pre-drain
  row; tests + reload. Sonnet lane: 5 more deliveries reviewed and approved (prescreen-skip rule cc33300782 unblocks
  class C; evidence-loss forensics; 13013 refusal; OOS-2026 findings; winsweep compile diagnosis; hygiene batch).
- **2026-09-15 (Tue, 07:2xZ, daily check)** — overnight: 7 Sonnet-lane deliveries reviewed and APPROVED (purge relaunch
  verification 350925f3b9 live; card intake prescreen default-OFF; 17 Edge Lab cards reworked, prescreen 18/18 KEEP re-run;
  QM5_9107 disk-bomb guard 3601a2974d default-OFF, 4 hidden-universe EAs now 44 GB class; Dukascopy P3 fail-closed 0/37 →
  reconciler boundary fix 867c215a96 → export-side fix c53a2760bb, governed T1 rerun b2c57e7f queued). No factory alert,
  counter 26/25. NEW OWNER order 06:5xZ: Creator→Critic→Formatter chain with cross-vendor critic → agent_chain.py
  (f426d249ef), used from today for every REVIEW delivery and for this daily check. Seat state: Codex over the budget line
  (80.0 % vs 73.2 %, throttle flag) and agy credential EXPIRED (401, OWNER re-login needed) → cross-vendor critic for
  Claude-lane deliveries falls to Opus (flagged) until Friday. Today's sprint work (unchanged): pre-drain churn fix + reload,
  chunk 85 + Q08 reruns 21507/20266, Weg 2 dispositions, D4 profile V3 builder, F4 FTMO demo package. Blocker of the day:
  D4 (profile V3 + controlled T_Live restart plan) — owner Claude; nothing waits on the OWNER except the agy re-login.
- **2026-09-15 (Tue, 07:4xZ)** — OWNER: "Freifahrtsschein deckt 1 bis 3, Market Watch mache ich Sonntag / AGY CLI habe ich
  eingeloggt" → decision file `decisions/2026-09-15_owner_freifahrtsschein_scope_1_to_3.md` (6646c3b217); manifest v2
  rev 3 `owner_signature` set by reference (2954c4bc5c, Q16 check 3 closed for all 7 new sleeves); 11.0 % risk step now
  has its decisions/ record; monitor attach inside D6 covered; agy back (98.4 % quota) → cross-vendor critic available
  again. Critic findings of the daily check mapped: B1/B2/B3/B10 closed by the OWNER line, B9 sequence fixed (D3/D6),
  B8 FTMO content decided (F3), B12 (.DWX in a staged live preset) and B4/B5 (Q16 cell counts, Codex-owned checks 1/10
  → re-owned by Claude) are today's work items before D4.
- **2026-09-15 (Tue, 08:0xZ)** — D4 closed: reproducible Book2 profile (builder + semantic verify), presets staged, T_Live_ON
  pointer, Sunday ceremony script with green preflight; check 1 re-scoped to SHA256 identity (no recompile on T_Live, July
  precedent + identity rule), 1537 sleeve-calendar dependency bound (Common/Files, sha 401E0D91…). Sunday sequence: OWNER Market
  Watch → `tlive_book_cutover.py apply --i-am-orchestrator` → verification → governor enforce (adapter dry-run first, then
  `--governor-apply` once the monitor v2 snapshot reports v2). Next: F4 FTMO demo package.
