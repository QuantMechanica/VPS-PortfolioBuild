# ULTRACODE-Programm 2026-07-26 — „Woran scheitert unser Erfolg"

Status: **v2 (Claude, post-challenge)** — Codex verdict PROCEED-WITH-REVISIONS
(`docs/ops/evidence/2026-07-26_codex_challenge_ultracode.md`); all revisions below are
BINDING for the build wave. v1 text retained beneath for the record.

## v2 — Challenge integration (binding deltas)

**Cross-cutting (from "Missing items" + sequencing):**
- Live factory DB = `D:\QM\strategy_farm\state\farm_state.sqlite` ONLY; every acceptance
  command prints its resolved DB path; repo-local `state\farm_state.sqlite` is NOT the queue.
- Builders work base-SHA-pinned (isolated worktrees) for any file a live process imports or
  a scheduled task rereads (`terminal_worker.py`, `farmctl.py`, `q10_confirmation.py`,
  `health.py`, `morning_brief.py`, watchdog/supervisor scripts, LiveVsBook path). Patches
  are STAGED; merge + worker restart + claim canary happen ONLY in tonight's Factory-OFF
  window. New inert files (docs, unscheduled scripts) may land directly.
- ALL activations (claimant merge, backfills, schema activation, task installs/repoints,
  supervisor restart, arming) = tonight's OWNER window. Factory-OFF does not itself
  authorize T_Live or money actions.
- Tonight's TOTAL_RISK12 written approval is preceded by the WS-C/WS-D audit outcomes or
  explicit OWNER acknowledgment of each UNKNOWN (runbook updated accordingly).

**WS-A+H (REVISE):** control point = `terminal_worker.py` `_priority_pending_query` /
`claim_atomic` (single shared ordering contract; farmctl secondary claimant delegated or
removed). Recovery work = eligibility-aware **idle-only cap** (Operating Rule 22), durable
rolling ledger advanced inside the claim's BEGIN IMMEDIATE txn — NOT a 20 % reservation.
Backfill/revert = compare-and-swap with pre/post-image hashes + batch marker. H: only the
authenticated Q08 insufficient-trades family reclassifies to INVALID, evaluated BEFORE the
generic infra return; genuine launch/transport/report/timeout failures stay INFRA_FAIL;
read-only corpus diff of every row whose classification would change. Acceptance adds a
multi-connection contention test. Note: WS-A does NOT "fund" WS-B — density rows use the
existing `priority_track` lane immediately.

**WS-B (REVISE):** order inverted. B1 canonical finite-horizon FTMO objective + ONE
admission contract (DL DRAFT; resolves ftmo_qualification-vs-research-engine split). B2
adjudicate 13213/USDJPY, 13301/GDAXI, 12969, 20007 WITHOUT relaxing gates (Q09 verdicts
respected). B3 rerun the sealed density model read-only → residual gap. B4 sourcing
shortlist sized to the measured gap; any "3-5/wk motor" claim needs a pre-build estimate of
156–260 trades/yr + after-cost edge + orthogonality hypothesis. Cards = paperwork, never
acceptance. Known: 13128 ≈8 tr/yr and 12969 ≈40 tr/yr do NOT meet the density premise as-is;
FX session-fade risks the ratified commission-dead conclusion.

**WS-C (REVISE):** per-sleeve evidence inventory FIRST; hash-bind report/set/binary/symbol/
window; 12567/XNGUSD has NO Q10 row → UNKNOWN propagated honestly (23/24 ≠ "all"); windows
labeled by actual endpoint (2025-12-31, ~7 months old) — historical sample, not current
edge. Shadow fields staged via worktree; boundary fixtures (19.9/20/20.1, 24.9/25/25.1);
byte-for-byte no-change proof; output = decision evidence, never auto-removal.

**WS-D (REVISE):** direction is NOT recoverable from q08 streams (0 direction fields in
47,515 rows) — authoritative source = native MT5 report deals (`Type` buy/sell +
`Direction` in/out, FIFO pairing) reusing `ftmo_report_cost_reconcile.py` logic. Reconcile
native↔stream (count/net/SHA) BEFORE recosting; rates are a **current-rate swap scenario**
(source-bound URL+date), never "historical actuals"; UNKNOWN on any unreconciled sleeve;
whole-book result explicitly incomplete if a material sleeve is UNKNOWN.

**WS-E1 (REVISE):** ONE recovery authority (existing watchdog + resident supervisor — no
second loop, no 15-min task). E1 = observability/handoff: transition-deduplicated alarm
STATE (atomic file contract) consumed by briefing/cockpit; the Gmail FAIL route stays
disabled (no silent revival — alert consumer needs owner + freshness SLA). State-machine
fixtures for both sessions (missing/recovered/duplicate/maintenance/probe-unknown/launch-
failed/stale/reboot-suppression). Activation = evening window (launchers can enable experts).

**WS-E2 (REVISE):** briefing consumes the watchdog/supervisor atomic state (NO process
probes — Operating Rule 20); expected accounts/sleeves derived from the signed manifest
(no hard-coded 24); missing/stale/malformed = UNKNOWN/RED, never green-by-absence; red
reaches subject line; trial-dead prose generated from account state. Fixture-tested.

**WS-E3 (REVISE):** generalize the EXISTING parsers (`prepare_dxz_v2_liveops_profile.ps1`,
`verify_ftmo_round25_live_contract.ps1`) — no second parser; bind (account, server,
deployment_epoch, manifest_SHA, symbol, TF, EA, binary_SHA, magic, risk); disk-profile
truth SEPARATE from runtime truth (fresh post-start INIT_OK/magic heartbeat); detect
missing/duplicate/orphan/unparseable + exactly one AccountMonitor; run post-recovery and
periodically; read-only, no auto-correction.

**WS-E4 (REJECT → E4′ comparator repair):** cadence unchanged (Sunday). Repair
`portfolio_live_forward_from_logs.py` + `sunday_livevsbook_compare.ps1`: bind one signed
manifest SHA + deployment epoch; filter exact EA/magic/symbol/account identities; match
window/capital/weights/costs and SUM-of-sleeves Monte Carlo (no placeholder MC); atomic +
idempotent writes; UNKNOWN on incomplete inputs. Promotion to daily/money-gate only after
fixtures + read-only historical replay pass.

**WS-F (REVISE):** detectors authenticate provenance (EA/set/binary/report hashes, stress
telemetry, unrounded KPIs, min cohort) before flagging; reuse Q07's existing seed-
authentication evidence (no filename-derived seed identity); reason-specific outputs
(`seed_alias`, `stale_report`, `set_mismatch`, `deterministic_by_design`, …); KS check
binds baseline to manifest/hash + observed loaded-event proof; health.py production DB
handle becomes URI `mode=ro` + `PRAGMA query_only=ON`; runtime budget documented.

**WS-G (REJECT → G′ governor closure):** NO new Python guardian (split-brain money
control). G′ = close the ratified blockers of the EXISTING `QM5_13206_ftmo-account-governor`
+ `QM_FTMOGovernorPolicy.mqh` design (client wiring, golden parity vs `ftmo_trial_pulse.py`
as read-only oracle, target-before-day-4 latch, bootstrap, signed manifest, T6
verification). Enforcement lives in the EA timer path; exactly one armed authority; no
arming before the new trial account + OWNER-signed manifest.

---

Status history: v1 (Claude) — challenged by Codex 2026-07-26 (PROCEED-WITH-REVISIONS).
Authority: OWNER directive 2026-07-26 („geh das alles jetzt an … zuerst Plan, dann reviewen
und challengen, dann umsetzen"). Bilateral review separation binding: Claude-built → Codex
reviews; Codex-built → Claude reviews.

## Diagnosis being addressed (evidence-anchored)

1. Neither pillar produces meaningful cash flow today. DXZ book ≈11 %/yr on demo notional
   (91,754 / 8.2y / 100k const-SC), paid only fractionally via slow investor allocation.
   FTMO — the actual revenue engine — is blocked: trial dead, P(pass) 15–25 %, density
   backlog 2/317 intraday-flat.
2. Q10 certifies 8-year-average edge, not current edge (12567/XNGUSD: Q10 PASS full-history
   while last-half PF 1.032, sealed Q08 FAIL_HARD twice). No recency axis, no live-sleeve
   re-qualification.
3. Swap = $0 in every backtest since the 06-09 deferral; the book holds D1 overnight
   positions. Systematic optimism bias in every reported KPI.
4. Factory marginal product for DXZ ≈ 0 (today: two fresh Q10 PASSes at ΔSharpe −0.002 /
   −0.006). Queue = 2,137 generic Q02 retests while the FTMO-relevant class is empty.
5. Live-ops brittle at the money edge (2026-07-26 reboot: autostart guard refusal, watchdog
   silent 6 h, live chart lost from profile, 06:00 briefing carried zero T_Live status).
6. Vacuous-gate CLASS (5 instances found reactively: Q07 paper-stamps, WP-9 basket stress
   bypass, 1567 missing seed input, KS gross-vs-net, T5 dead engine). No standing
   automated vacuousness audit.
7. FTMO supervisor not built; new trial account pending (OWNER).

## Non-goals / hard rails

- NO T_Live writes outside the OWNER-gated Sunday-evening session (runbook governs).
- NO gate-verdict change goes live without an OWNER-ratified decision record. Recency axis
  ships in SHADOW MODE (metrics computed + logged, verdict unchanged) + DL draft.
- No invented commission/swap/DST values — every swap number carries a cited source.
- Backtests are never throttled; queue changes re-order, they do not starve (Q02 keeps a
  floor share of slots).
- Factory stays ON during builds; no manual exec sessions that mutate factory state; builds
  serial; explicit pathspecs on commits; farmctl only from C:/QM/repo.
- decisions/ records are immutable once dated; new decisions get new files.

## Workstreams

### WS-A — Queue-Rebalancing (farmctl priority) + WS-H farmctl Q08 reason-preservation
Owner: Opus (single agent — both changes touch farmctl.py, must be serialized).
- A1: Priority adjustment in the claim/priority path: deprioritize the Q02 PF-floor retest
  class below (i) deep phases Q03+, (ii) density-class/force_build items, while reserving a
  configurable floor share (default 20 %) of claims for the retest pool so it drains slowly
  instead of starving. Class detection must use an explicit payload marker — if the retest
  rows carry none, add the marker via a one-shot, snapshotted backfill script (reviewed,
  reversible), never by string-guessing reasons.
- A2 (=WS-H): `_derive_phase_runner_verdict` returns generic ("INFRA_FAIL","INFRA_FAIL")
  for Q08 tooling infra; wire `_q08_dominant_invalid_reason` so the specific sub-gate
  reason survives (Codex batch-2 follow-up). Plus tests.
- Acceptance: unit tests on the priority ordering (retest vs deep-phase vs density claims,
  floor share honored); before/after claim-order snapshot from a read-only DB query;
  no change to claim_atomic semantics.
- OWNER gate: direction ratified by today's directive; a dated decision record documents
  the ordering rule and the rollback (single constant / marker removal).

### WS-B — Density-Motor-Sourcing-Sprint (the money workstream)
Owner: Opus (research+mechanization). G0 review: Codex (reciprocal Builder≠Approver).
- B1: Sprint spec: target class = intraday-flat (EOD flat, no overnight), session/event
  anchored, news-filter compatible, trade density ≥ 3–5/week per symbol, FTMO-compliant
  (daily-loss aware sizing), venue FTMO first.
- B2: 5 mechanized Strategy Cards from evidence-backed families (internal lineage first,
  citations R1-R4 mandatory, literal TF token in body, target_symbols frontmatter):
  (i) vol-gated gold ORB EOD-flat (20007 lineage), (ii) index open-drive / pre-FOMC drift
  generalization (13128 lineage), (iii) gotobi/fix-window family extension (12969 lineage),
  (iv) session-fade major-FX (doctrine-compliant limits-to-arbitrage story required),
  (v) one SSRN-mine candidate from the 07-20 nine that fits intraday-flat.
- B3: Cards enter G0 → Codex G0-verdict → force_build priority into the normal chain.
- Acceptance: 5 cards passing the approve-card validator (year+DOI/URL in body, real flat
  ea_id), Codex G0 verdicts recorded; queue rows created for approved cards.

### WS-C — Recency axis (SHADOW) + live-sleeve decay audit
Owner: Opus. Review: Codex.
- C1: q10_confirmation.py computes recency metrics (trailing-24-month PF, trade count,
  net) into the aggregate ALWAYS; verdict logic untouched (RECENCY_AXIS_ENFORCED=False
  constant). Tests: shadow fields present, verdict unchanged on fixtures.
- C2: One-shot audit script: recompute trailing-24m PF for ALL 24 live sleeves from
  existing Q10 evidence (trade lists in the aggregates/report CSVs); output a ranked decay
  report for tonight's session. Read-only.
- C3: DL DRAFT decision record: proposed enforcement rule (e.g. Q10 PASS additionally
  requires trailing-24m PF ≥ 1.0 at ≥ floor trades — exact anchors argued from the C2
  distribution, not invented) + quarterly rolling sealed re-Q08 for live sleeves. Marked
  DRAFT/pending-OWNER.
- Acceptance: C2 report exists with per-sleeve numbers + evidence paths; C1 tests green.

### WS-D — Swap closure
Owner: Opus (calc) + research sub-task. Review: Codex.
- D1: Source real swap rates for the 15 book symbols (DXZ/Darwinex) + FTMO equivalents:
  primary = broker-published specs (web, cited URL + retrieval date); cross-check vs MT5
  symbol specs where readable without touching T_Live (FTMO terminal specs acceptable).
  NO invented values; unknown = flagged unknown.
- D2: Swap-adjusted book recompute: from the sealed q08 trade streams (entry/exit
  timestamps + direction — verify the stream schema carries direction; if not, derive from
  per-trade sign convention documented in the exporter), nights held × swap rate (incl.
  triple-swap day per venue convention) → per-sleeve annual swap drag → FINAL24b and
  FINAL23 KPIs WITH swap. Report both books' Sharpe/MaxDD/net deltas.
- D3: venue_cost_model.json extension proposal + decision record DRAFT (adoption into
  tester defaults is a factory-wide config change → OWNER visibility tonight).
- Acceptance: per-symbol swap table with sources; swap-adjusted KPI table; explicit list
  of assumptions (fill times, triple-swap day, contract size mapping).

### WS-E — Live-Ops-Härtung
Owner: Opus (watchdog escalation — live chain), Sonnet (briefing Ampel + chart inventory +
LiveVsBook cadence). Review: Codex.
- E1 (Opus): T_Live_Watchdog.ps1 + Live_MT5_SessionSupervisor.ps1: if T_Live process
  absent > N min (default 15): (i) attempt session-aware start via existing T_Live_ON path,
  (ii) write ALARM state file, (iii) surface via the EXISTING FAIL-digest channel (no new
  ping channels — OWNER rule). Read both scripts fully first; minimal diff; -NoReboot
  semantics preserved. Scheduled-task XML changes are STAGED (install only after Codex
  review passes; installation is a Claude ops action, documented).
- E2 (Sonnet): Morning briefing: first block = status lamp line — T_Live proc up y/n,
  FTMO proc up y/n, chart inventory == deployed manifest y/n (parse profile .chr files
  read-only vs manifest), news calendar age, last KS/DD-guard state. Red lamp = first line.
- E3 (Sonnet): Daily chart-inventory check script (read-only on T_Live profile files)
  writing a state JSON the briefing + cockpit consume; scheduled daily.
- E4 (Sonnet): QM_NewBook_LiveVsBook cadence Sunday → daily (idempotent), keep Sunday deep
  version.
- Acceptance: dry-run outputs for E1-E3 against the live filesystem (read-only), task XMLs
  staged + install commands documented, tests where scriptable.

### WS-F — Standing vacuousness audit (health.py)
Owner: Sonnet. Review: Codex.
- Checks: (1) Q05==Q06 stress-identity detector (identical PF/trade-count pairs on recent
  runs), (2) Q07 zero-variance detector (all seeds identical), (3) trailing-7d INVALID
  rate per phase vs threshold, (4) KS baseline dormancy count (live sleeves without loaded
  baseline), (5) seed-authentication failure rate. Each = one health check emitting the
  standard _check tuple; read-only DB/filesystem; tests with synthetic fixtures.
- Acceptance: checks fire on synthetic vacuous fixtures, quiet on healthy fixtures; wired
  into the health runner.

### WS-G — FTMO-Supervisor
Owner: Opus. Review: Codex.
- Reads AccountMonitor event logs (MQL5\Files\QM\ on the FTMO terminal) → tracks daily
  P&L vs FTMO daily-loss/total-loss limits with configurable buffers → escalation ladder:
  state JSON → FAIL-digest alert → halt-file write (the EAs' manual-halt channel) at the
  hard buffer. NO trading actions, no terminal control. Designed to be armed when the new
  trial account (OWNER) goes live. Scheduled task staged, not installed until trial exists.
- Acceptance: unit tests on limit math (incl. FTMO daily reset convention, broker-time
  GMT+2/+3), dry-run against the dead trial's logs.

## Sequencing

1. This plan → Codex adversarial challenge (SOL MAX): wrong priorities? missing points?
   unsafe changes? better decomposition? Explicit verdict per workstream.
2. Claude revises plan per challenge (recorded in this file, v2 section).
3. Implementation wave (parallel agents; farmctl serialized inside WS-A agent):
   Opus: A(+H), B, C, D, E1, G. Sonnet: E2-E4, F.
4. Full test pass; Codex mega-review of ALL Claude-built diffs (bilateral rule); Claude
   reviews anything Codex built (expected: none — Codex is challenge/review lane).
5. Commit series per approved grouping; ops-task installs (E1-E4) after review; runbook +
   memory + evening-session handoff. Canary-50 and T_Live deployment remain in tonight's
   OWNER session, untouched by this programme.

## OWNER gates (explicit)

- Recency ENFORCEMENT (C3 DL) — tonight.
- Swap model adoption into tester defaults (D3 DL) — tonight.
- Queue-rebalance decision record — tonight (direction pre-ratified).
- FTMO supervisor ARMING — when new trial account exists.
- Everything T_Live — Sunday-evening session only.
