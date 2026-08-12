# Factory Audit & Maintenance — 2026-07-24

**Operator:** Claude (board-advisor lane, canonical checkout `C:\QM\repo`, branch `agents/board-advisor`)
**Method:** 4 parallel recon agents (Opus/Sonnet) + 3 parallel per-EA compliance evidence agents + 1 framework ground-truth agent (Opus) + independent Codex compliance audit (gpt-5.6-sol @ effort max, dispatched through the sanctioned agent-router queue — task `014c58ce`, no detached session, factory automation untouched). One cross-review round Claude↔Codex. All claims carry evidence paths; raw snapshots in `docs/ops/source_harvest/audit/evidence/`.
**Scope guard honored:** read-only on T_Live and T1–T10, no Factory_OFF, no deployments, no broker actions, no terminal starts. Codex reasoning effort was temporarily raised (`~/.codex/config.toml` `model_reasoning_effort low→max`, backup `config.toml.bak-2026-07-24-audit-effort`) per audit directive and is reverted at audit close (see §7).

## Executive Summary

The factory is **structurally sound and running**: all 14 gates Q00–Q13 are wired with fresh evidence, 9/9 enabled workers are saturated (T5 parked by design), the live book (24 sleeves, DXZ acct 4000090541) is loaded and clean, and every live magic satisfies the `ea_id*10000+slot` contract with zero collisions. Four real problem clusters exist:

1. **Q03 is degraded** — 35 INFRA_FAIL / 0 PASS in the 6h window before the audit; runner crashes before writing `summary.json`. This single-handedly drives `farmctl health` to overall=FAIL. Codex triage tasks are already routed but the failure class is live.
2. **The generic build lane was quadruple-blocked** — dirty-tree guard (regenerated `event_vocabulary.json`, a self-blocking recurrence because the file is in no auto-commit set), `CODEX_LOW_TOKENS.flag`, `CLAUDE_DISABLED.flag`, and a saturated codex queue, while 352 approved cards await build. The dirty-guard leg was cleared during this audit (commit `8154d302f`); the recurrence fix is FB-01.
3. **Live-book compliance has two systemic gaps** (full matrix in `COMPLIANCE_MATRIX.md`): the **max-DD kill channel is not fed by any live process** (KS_PORTFOLIO_DD default-off, external-signal-driven, no writer) and **pre-fix killswitch-channel binaries remain deployed** (P0.3 recompile debt, scheduled to be retired by the 26.07 wave). Additionally one live EA (13213) was missing from `ea_id_registry.csv` — backfilled during this audit (commit `51778300b`).
4. **Generated state surfaces have drifted from ground truth** — `pipeline_state.json` per-EA data contradicts `work_items` on 5/5 spot checks (191/191 EAs "NOT_RUN"), `live_book_pulse.py`'s preset parser matches 0 of the 24 deployed presets after the rename to `NN_SYMBOL_TF_*.set`, and the live-book manifest is a stale 23-sleeve DRAFT. None of these affect trading; all of them poison any consumer that trusts them.

Everything else is hygiene-level: terminal RECYCLE piles (historical, not a backlog), 189 future-dated work_items rows (grew 63× since the 07-09 audit flagged it), 30 agent_tasks rows with a malformed composite agent label written by an ad-hoc board-advisor session, stale P*-era report relics, ~25 dead infra scripts, 9 scheduled tasks pointing at deleted one-off launchers, and a suspected duplicate include (`QM_Branding.mqh` — later verified byte-identical and cleaned up, see §6).

---

## 1. Pipeline Integrity (Scope 1)

**Verdict: intact, one degraded gate (Q03), build lane was blocked.**

- **Gates Q00–Q13 all wired.** Runners resolve via `farmctl.py:130-140` to existing scripts under `framework/scripts/`; card intake (Q00/Q01) and OWNER gates (Q11–Q13) correctly have no work_items rows. Fresh evidence: Q02 05:11Z, Q04 04:12Z, Q05 04:31Z, Q06 03:49Z (2026-07-24), Q07 07-23 15:03Z, Q08 07-23 17:54Z, Q09_PORTFOLIO 07-23 07:49Z (100 done / 31 PASS_PORTFOLIO), Q10 07-22 (8 PASS). `q09_news_mode.py` is a dormant TODO stub with zero work_items ever — superseded by Q09_PORTFOLIO, dormant by design. Evidence: `evidence/pipeline__work_items_gate_activity.txt`, `evidence/pipeline__farmctl_pipeline.txt`.
- **Q03 DEGRADED (top pipeline finding):** 35 INFRA_FAIL / 0 PASS in the last 6h; runner crashes before writing `summary.json` (empty `evidence_path`), symbols span GDAXI/NDX/GBPUSD; drives `farmctl health` overall=FAIL via `phase_infra_graveyard`. Codex triage is already routed (14 `triage_failure` PIPELINE + 3 `q02_infra_repair`). Evidence: `evidence/pipeline__farmctl_health.txt`, `evidence/pipeline__q03_infra_fail_sample.txt`. → FB-02.
- **Workers/saturation healthy:** 9/9 enabled terminal_worker daemons alive (T1–T4, T6–T10) matching `worker_pids.json`; T5 intentionally parked (`disabled_terminals.txt`, account-missing since 07-07); saturation 9 active backtests / 9 effective slots; live process scan path-anchored with T_Live + FTMO terminal excluded. One hung row (QM5_10485 USDJPY Q02, 84.6m > 45m timeout) will be released by pump `active_timeouts`. Evidence: `evidence/pipeline__live_worker_scan.txt`, `evidence/pipeline__farmctl_mt5_slots.txt`.
- **Orchestration lanes on-cadence** (Missed=0; heartbeats fresh), dispatch idle-skipping by design: claude lane disabled by quota governor (`CLAUDE_DISABLED.flag` set 07-23 22:38; agent_registry claude enabled=0), codex throttled (`CODEX_LOW_TOKENS.flag` set 07-23 10:53), last real dispatches codex 07-23 16:00Z / gemini 07-23 16:30Z. **Note:** Operating Rule 13 ("gemini scheduled lane defective, keep disabled") is superseded in practice — the lane runs agy and completed a real dispatch 07-23 16:30Z rc=0; the rule text is stale. → ESC-04.
- **Pump lane incident (self-healed):** pump run PID 15384 died ~06:57 leaving an orphaned `pump_task.lock`; three cycles no-opped on the not-yet-stale lock until the 20-min staleness cleared it (07:18). Health blind spot: `pump_task_lastresult` reads the skip's exit 0 as OK — a persisted lock with dead PID is invisible. → FB-06.
- **Build lane quadruple block:** (1) dirty-tree guard `blocked=True` (`farmctl.py:309-353`, consumers `:6526,:9822-9833,:10027-10032`) on `event_vocabulary.json` + public-data JSONs + this audit's evidence dir; (2) `CODEX_LOW_TOKENS.flag`; (3) `CLAUDE_DISABLED.flag`; (4) codex queue saturated — while **352 approved cards await build**. Cleared leg: `event_vocabulary.json` committed (`8154d302f`). Recurrence: the file is regenerated by `generate_event_vocabulary.py` on new EA event names but is in neither `SHARED_BUILD_PATHS` (`farmctl.py:78-85`) nor the pump auto-commit set (`farmctl.py:9307+`) — it will re-dirty and re-block. → FB-01.
- **9 scheduled tasks point at deleted scripts** (one-off Balke/NDX/Sonnet launchers, e.g. `QM_Agy_BalkeWindows` → missing `launch_agy_balke_windows.ps1`); all Ready-state relics with no future trigger value. Full table: `evidence/pipeline__scheduled_tasks.txt` + salvage notes. → FB-09.

## 2. EA Inventory Reconciliation (Scope 2)

**Verdict: live book clean and fully evidence-backed; registries lag; every monitor surface around it has drifted.**

Live truth (T_Live journal `C:\QM\mt5\T_Live\MT5_Base\logs\20260724.log`, 05:17 session, cross-checked against `live_book_pulse.json` 05:00Z and deployed presets/binaries): **24 EA instances, 21 unique ea_ids** (dual-symbol: 11165 AUDCAD+EURUSD, 11421 AUDUSD+EURUSD, 12567 XAUUSD+XNGUSD), account 4000090541, book equity 101,683.41, experts enabled. All 24 magics: `magic//10000==ea_id`, `magic%10000==slot`, status=active in `magic_numbers.csv`, zero mismatches, all sources + binaries + set files present. Canonical list: `evidence/inventory__live_eas.json`.

Discrepancies (detail in evidence files):
- **INV-HIGH-1 (fixed):** live+trading EA 13213 had no `ea_id_registry.csv` row → invisible to registry-based lifecycle/orphan tooling (the orphan scan indeed flagged its factory binaries as NOT_IN_REGISTRY). Backfilled under registry lock, commit `51778300b`.
- **INV-MED-1:** live-book manifest is a stale 23-sleeve **DRAFT** (`portfolio_manifest_sunday_23sleeve_DRAFT_20260711.json`): 3 manifest sleeves not live (10476, 10692, 10715), 4 live sleeves not in manifest. The T_Live §hard-rule workflow expects an OWNER-approved manifest matching the book. → FB-04 / ESC-02.
- **INV-MED-2:** `live_book_pulse.py` preset parser finds 0/24 presets — its `PRESET_FILE_RE` still expects `slot<N>_..._magic<magic>.set` but deployed presets were renamed `NN_SYMBOL_TF_QM5_<id>_<slug>.set`; 23× `manifest_missing_live_preset` alarms are parser artifacts. The pulse verdict=ALARM is therefore noise — a real alarm would drown. → FB-03.
- **INV-LOW-1:** 4 stale EA-log streams (10476, 10692, 10715 last events 07-19; 10940 07-05) still parsed into `sleeves_from_ea_logs` (28 ≠ 24) — the documented stale-stream hazard, still alive.
- **INV-LOW-2:** swapped-out/retired EAs keep `status=active` in both registries (10476, 10692, 10715, 10940 + their magics); their `.ex5` remain in the Live EAs folder (except 10940).
- **INV-LOW-3:** `portfolio_candidates` table lags reality: ~17 of 33 rows are already-live EAs still marked `Q12_REVIEW_READY`; two live EAs marked `EVIDENCE_STALE`. No terminal LIVE state exists in that table.

**Candidates (Q11–Q13 queue):** 6 distinct Q10-PASS work_items not live (10123, 10128, 10145, 10183, 13013, 20048), plus 5 review-ready portfolio candidates (10700, 10815 EURUSD, 10815 GDAXI, 12474, 1567 XAGUSD) and 4 former-live (10476, 10692, 10715 swapped out; 10940 retired). List: `evidence/inventory__candidates.json`.

## 3. Compliance Audit (Scope 3)

Authoritative cell-level result: `COMPLIANCE_MATRIX.md` (EA × check, evidence ref per cell) — synthesized from three independent per-EA evidence agents + framework ground truth + one deterministic whole-book scan of the QM event logs (`evidence/compliancefinal__qm_event_scan.json`, all 24 magics) and deployed presets (`evidence/compliancefinal__set_risk_scan.txt`), then cross-diffed against Codex's independent audit (44 FAIL / 2 MISSING over 232 applicable cells, 18-minute sol-max run). The two audits agreed on every material call (max-DD ×24, killswitch ×11, news-off ×3, magic/cap/daily-loss clean); all 8 divergent cells (6 divergence classes) were resolved to the stricter verdict. Codex's closing cross-review (single round) returned 6× CONFIRM — including fresh re-derivation of the killswitch set and an independent external max-DD scan — and 2 disputes (six pair-swapped magic identities in the dual-symbol rows, inherited from the inventory JSON; the divergence-cell count), both accepted and corrected in the matrix.

**Live book result (24 instances × 8 checks): 150 PASS / 40 FAIL / 2 MISSING.**

- Clean columns: magic registration (24/24, registry-wide 0 collisions over 15,186 rows), per-trade cap (all 0.04–1.0%, ≤ 1% ceiling; runtime cap 1% armed), daily-loss kill (KILL_SWITCH_INIT `daily_loss_halt_pct=3.0` log-evidenced for every magic), Friday close (default-on framework-wide; 10706 custom earlier 18:30; runtime FRIDAY_CLOSE events 07-17; **no separate weekend filter exists** — documented, not scored).
- **Max-DD kill: FAIL ×24** — channel armed in existence-trip mode but no producer writes any signal file (ESC-01). Not a per-EA defect; one decision fixes the book.
- **KillSwitch halt channel: FAIL ×11 instances / 9 EAs** — binaries predate fix `47f1d9709` (2026-07-05); runtime KILL_SWITCH_INIT shows the dead absolute `D:\QM\data\halt\...` path. These sleeves cannot be halted via the file channel at all (KS_MANUAL + KS_PORTFOLIO_DD). Retired by the 26.07 wave (ESC-03).
- **News filter: FAIL ×3** deliberate opt-outs (12778/13117 baskets set-disabled; 13128 compiled-in FOMC list, no stale-guard — ESC-05), **MISSING ×2** (10919/12969: calendar-loaded evidence but no per-magic native-calendar SELFTEST on those older binaries).
- **Risk mode: FAIL ×2** (10919 live preset carries `environment=backtest, risk_mode=FIXED` header; 12989 carries a DRAFT header label) — values behave correctly (PERCENT, RF=0), but no runtime enforcement exists to catch a mis-generated set, so the header contract is the only guard and it is violated (adopted from Codex, stricter-wins).
- **Framework-audit reconciliation** (EA_FRAMEWORK_AUDIT_2026-07-20 vs HEAD): P0.1/P0.2/P0.4/P0.5/P0.6 + P1.1–P1.6 are FIXED_IN_TREE (commits `5b21b9b1d`, `37196e79d`, `6e92c8062`, 07-20); P0.3 PARTIAL (recompile debt only); P1.7 OPEN (SeedRNG untouched, deferred); P1.8 PARTIAL (diagnostic added, dump not run). **Every fix requires a rebuild — no live binary (newest 07-17) carries the 07-20 bundle**, so P0.1 deinit-kill exposure is still live on all 24 sleeves until the 26.07 wave (ESC-03). Detail: `evidence/framework__audit_reconciliation.txt`.
- Candidates (15 rows incl. Codex's 8 strict Q10-PASS configs): magic/risk-mode/cap clean except 3 former-live rows MISSING factory sets; **10145 news-FAIL ×3** (legacy keys ineffective, Q10 metadata contradicts effective config) and **20048 friday-FAIL** (source-hardcoded off) both need re-gate/sign-off before admission (ESC-06).

## 4. State Drift (Scope 4)

**Verdict: DB is the only trustworthy surface; every generated mirror has drifted.**

- No `GOALS.md`/`TODO.md` at repo root (confirmed absent — expected).
- **pipeline_state.json is broken as a per-EA surface (HIGH):** generated 05:07Z by `scripts/build_pipeline_state.py` from `D:/QM/reports/pipeline` filesystem artifacts, NOT `work_items`; claims 191/191 EAs NOT_RUN while the DB holds 23,256 PASS verdicts; 5/5 spot checks disagree (e.g. QM5_10013: DB Q02 PASS×31 vs json NOT_RUN). Legacy P* keys present (benign only while nothing trusts the file). Nothing may key off it — and nothing documents that. → FB-05.
- **Timestamp corruption in work_items:** 189 rows with future `created_at=2027-01-01` (QM5_1081/1101/1209-1221 family) — the 07-09 audit saw 3 and recommended a health check that was never built (grew 63×); 2 rows carry bare-integer epochs in `updated_at`, breaking ISO comparisons. → FB-07.
- **RECYCLE is terminal, not a backlog:** router routes only BACKLOG/TODO; stale-lease release goes IN_PROGRESS→TODO, never RECYCLE→TODO. The 346 codex + 41 claude + 21 gemini RECYCLE rows are closed historical dispositions (410/420 build_ea, 302 updated <7d = the recent build-rework wave). No action needed; documented to stop re-litigating the "mountains".
- **Malformed agent label (MED, self-inflicted):** 30 agent_tasks rows with `assigned_agent='codex:agents/board-advisor'` — written by an ad-hoc board-advisor session via direct DB write (payload keys `active_repair_claim`/`active_repair_result` exist in zero source files). These rows are invisible to cockpit codex attribution (`render_cockpit.py:1650` matches exact `'codex'`). Undocumented schema drift. → FB-08.
- **Approval queue:** 6 of 7 REVIEW tasks carry completion verdicts ("VERIFY_COMPLETE", "committed main b74868681", …) but were never closed to APPROVED; worst is `589b946f` (agent=None, 58.4d). The 2 framework-P1 coordination tasks in REVIEW are intentionally parked for the 26.07 wave. 12 BLOCKED include two 52.7d `ops_issue` rows gating the Q11 portfolio-layer spec that is meanwhile delivered (Q09_PORTFOLIO 100 done, portfolio_candidates populated). → FB-10.
- **Cards:** 3,048 approved (reservoir ≫ router threshold 5; generic replenishment frozen since 05-22 by design), 244 in review (oldest 64d), 109 drafts. 1,317 Q02-pending work_items older than 14d (back to 06-09) — deep parked backtest FIFO tail, partly expected since backtests are never throttled, but undocumented.

## 5. Gate Logs / Approval Queue (Scope 5)

Snapshot 2026-07-24 ~05:11Z (evidence: `evidence/state__agent_tasks_counts.txt`, `state__agent_tasks_review_blocked_inprogress.txt`):

| state | count | notes |
|---|---|---|
| RECYCLE | 420 | terminal dispositions (see §4), not actionable |
| APPROVED | 149 | codex 89 / gemini 27 / claude 22 / none 11 |
| PIPELINE | 43 | incl. 23 under malformed `codex:agents/board-advisor` label |
| PASSED | 17 | |
| BLOCKED | 12 | 2× 52.7d Q11-spec (delivered → close), 3× genuine tester-resource, 2× board-advisor triage |
| REVIEW | 7 | 5 finished-but-unclosed + 2 intentionally parked for 26.07 wave |
| IN_PROGRESS | 1 | this audit's own codex dispatch `014c58ce` (expected) |
| TODO/BACKLOG | 0 | queue fully drained |

## 6. Orphans (Scope 6)

Read-only scan; nothing deleted. Detail: `evidence/orphans__*.txt`.

- **QM_Branding.mqh "divergence" — corrected 2026-07-24:** deep verification (git blob compare) showed both copies byte-identical; the initial "divergent content" claim was an autocrlf hash artifact. The un-included duplicate + its generator output path were removed as cleanup. → FB-11 (resolved), `evidence/fb11__branding_analysis.md`.
- **Stale P*-era relics (no readers):** `D:/QM/reports/pipeline/QM5_*/P2` (24 dirs) + `/P3` (23 dirs, all mtimes 05-26..28), `master_ea_p2_gate`, `master_ea_p25_gate`, `pipeline_operator/p2_*.log`, `tmp_codex_p8_test`, `pipeline_evidence_archive` — zero references anywhere. Safe-delete list → FB-12.
- **Factory `.ex5` vs registry:** 172 binaries (30 distinct ids) not in `ea_id_registry.csv` + 54 (18 ids) with registry status=retired across T1–T10. Caveat: several "unregistered" ids are registry-lag recent builds (2131 built 07-23; 3001-3005/4001-4005 experimental); genuine stale set is the older-mtime ids (9184, 9221, 9265, 10386, 13204, 13299, 13302; 13213 now resolved by the registry backfill).
- **Dead scripts:** 25 infra candidates with zero repo/task references (e.g. `safe_push.ps1` superseded by `push_repo.ps1`, `rotate_logs.py`, one-shot `backfill_/reclassify_/recover_*`); installers kept-for-reinstall flagged as dormant-by-design, not dead. "Unreferenced ≠ delete-safe" — list only.
- **Worktrees/branches:** 7 worktrees on branches fully merged into origin/main (Apr–Jun era: pipeline-operations, pdf-analyst, youtube-analyst, development-claude, gemini-orchestration-1, codex-q08-regen, claude-orchestration-4), 4 detached-HEAD worktrees >7d, 1 stray non-git dir (`codex-13140-index-20260711-0924`), 12 merged branches without worktrees prunable. Locked `src-futures-orderflow` is active (20023 wave2), not stale.
- **Disk:** D: 226 GB free / 77% used; `D:/QM/mt5` 608 GB dominated by purge-managed tester caches, no anomalous outlier; only notable artifact orphan is a 20 MB `cards_approved_bak_freqfill_20260625T151220Z`.

## 7. Maintenance Performed In This Run

| commit | change | finding |
|---|---|---|
| `8154d302f` | committed regenerated `framework/registry/event_vocabulary.json` (26 event names, count 6020→6165) — cleared the dirty-guard leg of the build block | §1 build block |
| `51778300b` | backfilled `ea_id_registry.csv` row for live EA 13213 (1 line, via farmctl registry lock/atomic write; no resolver regen, no compile needed) | INV-HIGH-1 |
| *(audit close)* | reverted `~/.codex/config.toml` `model_reasoning_effort` max→low after the Codex cross-review round | §Method |

All other findings are documented in `FIX_BACKLOG.md` (nothing else met the "P1 + compliance-relevant + <20 lines" bar without touching build/deploy surfaces this audit must not move).

**Implementation run (same day, OWNER directive "alles umsetzen"):** the full backlog
FB-01…FB-14 and the escalation recommendations were implemented in a follow-on run —
per-item status + commit hashes in the `FIX_BACKLOG.md` header, OWNER countersigns in
`NEEDS_FABIAN.md`. Highlights: Q03's real root cause found and fixed (evidence-binding
None-date regression `bd9c3e049`, not the suspected spawn args), live book-DD guard
built and scheduled (`8b00df9c9`, ESC-01), 24-sleeve as-deployed manifest live in the
pulse (`bf3f03a1a`), pulse preset parser repaired (`5562e8463`), pipeline_state per-EA
rewired to the DB (`b2469ef66`), DB/queue hygiene executed (`6e79b9ea9`), FB-11
corrected as a phantom finding (`7e11856d4`). Closing adversarial Codex review of the
implementation diff: task `2aa92baa` returned 7 CONFIRM + 7 DEFECTS. Disposition:
5 fixed same-run (#2 allowlist exact-match, #5 equity-observation freshness +
strict timestamp validation, #6 dead SYSTEM-profile common path removed, #7 signal
scoped terminal-local until book tagging exists, #10 downstream-FAIL now beats
READY — all re-verified), #11 became FB-15 (public-schema Q-label migration),
#13 rebutted with evidence (factory sets are UTF-8-no-BOM by convention,
gen_setfile.ps1:510). One deliberate divergence escalated to OWNER: no auto-halt
on telemetry loss (NEEDS_FABIAN item 6).

## 8. Risks / Blockers

- Q03 INFRA_FAIL class is live and eating queue throughput (mitigated by routed triage; root cause unconfirmed at audit time).
- Max-DD kill + killswitch-channel recompile debt are live-money-relevant; both are riding on the planned 26.07 wave — if that wave slips, the debt persists (see ESCALATIONS).
- Monitoring surfaces (pulse preset parser, pipeline_state.json, DRAFT manifest) currently normalize alarm noise — a real live-book alarm could be missed.

## 9. Recommended Next Step

Execute the 26.07 dual-book wave as planned (it retires P0.3 recompile debt + ships the P0 bundle), pre-wiring FB-01 (event_vocabulary auto-commit) so the wave's builds don't re-block, and decide ESC-01 (external KS_PORTFOLIO_DD feeder) before the wave so the max-DD channel ships fed, not just present.
