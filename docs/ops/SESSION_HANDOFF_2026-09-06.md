# Session handoff 2026-09-06 (~08:05Z) — CEO control loop, resume in a new session

Reason for the new session: the claude.ai Notion connector attaches only at session start (the OWNER
authorised it on claude.ai at ~08:00Z; the local `notion` MCP entry was removed). Everything below is
committed on `agents/board-advisor` (tip after this handoff: see `git log -1`).

## 1. Standing orders (unchanged)

- OWNER 02.09.: keep the loop running until the portfolio stands; keep the factory running.
- OWNER 05.09. 03:55Z: everything except purchases is released.
- Hard limits: T_Live AutoTrading toggle = OWNER only; never write T_Live or the live pointer; no purchases,
  no account creation by AI (NO-BUY); gate criteria/thresholds/verdicts/candidate pool/book rules = ROT
  (Vorlage + Mission-Control card, no Auffangregel); append-only verdict trail; evidence over claims;
  never commit `framework/registry/dxz23_execution_contracts.json`; commits with explicit pathspecs
  and trailers (Claude Fable 5.1 + Claude-Session; add Codex Sol/Astra co-author when integrating Codex code);
  subagents never commit/push; website deploy only on JA of `OWNER-DEC-WEBSITE-DEPLOY-20260905`.
- OWNER 06.09.: Mission Control shows only OPEN decisions + OWNER To-Dos; decided decisions live in the
  Vault archive; blocks "Ausnahmen & Datenqualität" and "Linear gate frontier" are gone; the cockpit
  self-refreshes every 5 s. Notion = marketing surface (Vermarktung), Vault = company documentation,
  the morning briefing is the only deliberate duplicate.

## 2. First actions in the new session (in this order)

1. Read `docs/ops/OPEN_ITEMS_STATUS.md` (top addenda of 06.09.) and this file; memory index is loaded automatically.
2. Confirm the scheduled task `QM_StrategyFarm_ClaudeOrchestration_15min` is still **Disabled** while an
   interactive session runs (duplicate-session race, memory 23./24.08.).
3. Re-create the fleet monitor (session-bound, the old one dies with the old session):
   Monitor tool, name "containment trips + 10-min fleet throughput summary", every 10 min:
   `python -X utf8 tools/strategy_farm/session_tools/tick_status.py` is the tick query; the monitor
   condition used before: containment_mode.json `enabled` flips to true OR fleet summary line
   (active cells, cells/10 min from `work_items` status='active' / done in last 10 min).
4. Re-issue the CEO control loop with ScheduleWakeup (~25 min) using the loop prompt in section 8.
5. Verify Notion: `mcp__notion__notion-fetch` with id `self` must return the workspace "Fabian's Notion";
   the hub page is `3d347da5-8f4a-810a-9e13-d8a06a6c5bd8`, the Morgenbriefing data source
   `9db97cf3-56bd-413d-bbc4-e9435ffcc824` (memory `reference_notion_marketing_hub_2026-09-06.md`).
6. Check the three local site servers (ports 8770/8771/8772). If any is down:
   `python tools/strategy_farm/session_tools/site_server.py C:/QM/deploy/qm-ops-refresh/tools/site-build/homepage-v4 8772`
   (8770 = `.../Website`, 8771 = `.../tools/site-build/astra-rework`), run in background.

## 3. Factory state at handoff

- Counter 11/25 (pipeline_state `operator_surface.book_guard.qualified_pairs`; public funnel-stats.json regenerated 11/25).
- Census ~100 MEASURED cells/h, 10 workers, ~9,650 cells pending (13 programmes in progress = path to 24 in ~3-4 factory days);
  lock busy < 10 per 15 min after the claim-lock fix; containment `enabled:false`; RAM free 20-30 GB, D: ~68 GB.
- Refutation rule (OWNER-DEC-M11 = YES, Option A): count Q14 closures with verdict KEEP_INCUMBENT/CHALLENGER_PROMOTED
  after 2026-09-06 06:17Z (baseline 12 KEEP, 0 promoted); the rule fires after 5 more without a promotion.
- STRUCTURAL: under DSR V2 every new Q08 without a sealed search ledger ends INVALID (11167/XAUUSD 06:32Z;
  the 11015 successor 34d0e1ba will too) → no new Q11 survivor, counter capped at 24 until the trivial-cohort
  seal lands: Codex ticket `f4505fb9` (IN_PROGRESS; Codex already committed evidence e71d50e9aa "DSR single-configuration
  implementation and honest three-EA replay" — integrate its branch `agents/codex-dsr-trivial-cohort-20260906` when it reaches REVIEW).
- Six stress-guard-fixed pacer EAs (41171, 41358-41362; fix bb62d69619) recompiling: compile rows 411cfb83, 001294f0,
  6d61317d, 37176af0, a464f322, a4d9fc3a released 07:5xZ. On COMPILE_OK: append-only Q02 reruns per EA:
  `farmctl enqueue-backtest --ea <EA> --phase Q02 --from-work-item-id <prior Q02 row> --append-only-rerun-of <prior Q02 row>
  --rerun-reason "..." --expected-current-ex5-sha256 <new ex5 sha>` (new identity; old chains stay evidence).
  QM5_41319 stays terminal on its Q02 DRAFT_DEFECT (zero trades; card rule), no retirement tool for built EAs.
- Q02 is starved behind the census by claim order (OWNER decision, do not change); 775 Q02 rows pending incl. the canaries and 41143 (2ed1bb9e).
- Backup guard fix 91d127d791 proven (hourly snapshot 06:00Z, retention runner clean). PumpMaintenance runs every 4 h (temp rollback).

## 4. Agent lanes

- Codex lane (Sol) runs 15-min cycles + the fleet pacer (`QM_StrategyFarm_CodexFleetPacer`, commodity/fx/backlog missions,
  commits directly on `agents/board-advisor`). Open Codex items: `f4505fb9` (trivial cohort, P0 for the counter),
  `690fc42a`/`abd0a457` (build_check predicates), D2 sibling builds `0ceafe5f`, pacer build `4b622f5c`.
  Integration recipe: `git cherry-pick -n <sha>` (apply --3way sometimes fails on already-present hunks), run the tests,
  commit with pathspecs + Codex co-author, `close-review <full id>`.
- Decision-bound Claude tasks: all closed (M06 244ec170, M11 9bed9f32, M13 a7ed2ad5 APPROVED after Sonnet acceptance fan-out).
- Parked chain on the calendar repair (E1): 1721f3a1 (OOS-2026 repair --apply), 49a8c88b (E4), 90431302 (E2-Mittel).

## 5. Mission Control / OWNER To-Dos

- Open cards: `OWNER-DEC-WEBSITE-DEPLOY-20260905` (+ Dukascopy due 14.09., MQL5CAND deferred).
- OWNER To-Dos (feed `D:/QM/reports/state/owner_todos.json`, CLI `tools/strategy_farm/owner_todos.py list|add|done|import-vault|sync-vault`):
  `OWNER-TODO-20260906-FTMO-DEMO` (free demo account tonight; on report: credentials only in the private record,
  take the client-area terms + duration cap, mark DONE, add the follow-up To-Do terminal login / PARKED→RUNNING),
  `OWNER-TODO-20260906-NOTION-AUTH` (integration token for the publisher), plus 15 imported Vault items.
  The Vault OWNER.md was migrated (backup `12 ToDo/AI ToDos/Archive/OWNER_2026-09-06_pre_todo_migration.md`).
- Cockpit render task `QM_StrategyFarm_Cockpit_2min` runs every 1 min; the page reloads on a new render stamp
  (file:// path: guarded 5-s timer). The reload guard ignores the decision FILTER controls and pauses only while a
  note field is focused or non-empty (verified in `render_cockpit_v2.py`, `inputBusy`).
- New receipt → `python tools/strategy_farm/owner_decision_execution.py --apply` → execute the plan → REVIEW →
  independent acceptance (Sonnet fan-out) → APPROVED.

## 6. Website (local only, http://127.0.0.1:8772/)

- Round 2 done: Inter headline, STEEL+EMERALD accent, GARCH candle field, Astra funnel v2 (curved, no ellipse),
  archive as a 26-column matrix (3,339 rows), richer strategy cards (tagline leads, family pattern labelled,
  contradiction guard), hero lead 22 words, Astra mechanical polish applied (contrast, Inter on archive pages, sticky header).
- OWNER judgement calls still open: primary CTA ink vs emerald; the hero candle animation stays (OWNER wanted it).
- Deploy only on JA: copy homepage-v4 → `Website/`, sitemap fragment, push `refresh/apple-2026-09` + Netlify + live check + deploy log.
- Design skill: `skills/web-design-taste/SKILL.md` (two regimes; verify list) — every design agent reads it.

## 7. Notion (marketing surface)

- Hub "QuantMechanica · Vermarktung" (private draft) with Positionierung, Website, Blog & Content, Social & YouTube,
  Darwinex & FTMO Außendarstellung, database "Morgenbriefing" (first entry 2026-09-06 posted).
- Publisher `tools/strategy_farm/notion_morning_brief.py` integrated, `enabled=false` until `NOTION_INTEGRATION_TOKEN`
  is in `.private/env` (OWNER To-Do). Next: migrate the archived Notion material (Brand Book, Content Strategy,
  Episode Guide) into the hub sections; post the daily briefing after the 06:00 mail.

## 8. Loop prompt to re-issue (ScheduleWakeup, ~25 min)

CEO-Kontroll-Loop (OWNER-Auftrag 02.09.: „Weitermachen, bis Portfolio steht, mit Loop kontrollieren und Fabrik am Laufen halten!"; 05.09. 03:55Z: alles außer Kauf freigegeben). Tick-Pflichten: (1) Status-Query via tools/strategy_farm/session_tools/tick_status.py (REVIEW-Rückläufer, IN_PROGRESS, TODO, Census MEASURED/h + /15min, aktive Zellen, Gate-Abschlüsse 3h, MC-Receipts, Zähler = pipeline_state book_guard, live 11/25); Lock-Attribution 15 min (Ziel <20); Containment, free_gb, D: free, Worker 10, Server 8770-8772; Widerlegungsregel: Q14-Closures KEEP/PROMOTED nach 06.09. 06:17Z zählen (Baseline 12, feuert bei 5 ohne Promotion); (2) Compile-Welle der sechs reparierten EAs (41171, 41358-41362) → COMPILE_OK → append-only Q02-Reruns mit --expected-current-ex5-sha256; 11015 Q08-Nachfolger 34d0e1ba beobachten (wird unter V2 INVALID, bis f4505fb9 landet); (3) Codex-Rückläufer integrieren (cherry-pick -n, Tests, Trailer Codex Sol) + close-review mit voller ID: f4505fb9 (triviale Kohorte, P0), 690fc42a/abd0a457, D2-Sibling-Builds, Pacer-Builds (Build-Review-Checkliste, record-build-SOP); (4) Website: lokal fertig auf 8772; Deploy nur bei JA auf OWNER-DEC-WEBSITE-DEPLOY-20260905; (5) Mission Control: bei neuem Receipt owner_decision_execution.py --apply → ausführen → REVIEW → Abnahme → APPROVED; OWNER-To-Dos pflegen (FTMO-Demo, Notion-Token); (6) Notion: Morgenbriefing täglich, Hub-Migration; (7) Fabrik: RAM-Floors (free <8 GB = handeln), Containment enabled:false; (8) OPEN_ITEMS/Memory/Vault-Addenda je substanziellem Ergebnis; Wake neu planen (~25 min). Ende erst bei qualified_pairs ≥25 mit echtem Zensus UND vorbereiteter Buch-Zeremonie.
