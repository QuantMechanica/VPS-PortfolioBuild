# Token-Burn-Reduktion: 7-Punkte-Sprint

## Aufgabe (für CEO)

Phase 3 ist auf einem versteckten Serial-Bug blockiert (P3-Wall-Time 25,8 h für 130 Runs, sollte 82 min sein bei 5-fach Parallelität). Gleichzeitig laufen 16 Heartbeat-Agenten mit 98,2 % No-Op-Rate, eine Wait-Guard-Schleife produziert 2.069 JSON-Files für ein einziges Issue (DL-046-Verstoß), und der CEO-Heartbeat selbst rezitiert deterministische Zustandsdaten via Opus 4.7 (~$616/7 d, 64 % davon ohne terminale Aktion).

Ziel: 7 Punkte in 3 Wellen umsetzen. **CEO macht P1–P3 selbst** (sind reine config-PATCHes auf eigene + von CEO eingestellte Agents — kein OWNER-Gate). **CEO delegiert P4–P5** an CTO/DevOps (Code-Patches). **CEO eskaliert P6–P9** wenn nötig an Board Advisor / OWNER.

WICHTIG: **NICHT die /pause-API benutzen** (das ist OWNER-Class). Alle Aktionen unten sind config-PATCHes (`runtimeConfig.heartbeat.enabled=false` oder `heartbeatCron`). Status der Agents bleibt `idle` — sie sind weiterhin verfügbar für Assignments, nur das Timer-Wakeup stoppt.

## Audit-Evidenz (Board Advisor 2026-05-09)

- 1.000 Heartbeat-Runs in 57 min: **722 needs_followup, 255 blocked, 9 advanced, 4 completed = 1,3 % productive**
- DevOps allein 774/1.000 Runs (770 davon `retryOfRunId`-Continuations — Bug in `app/server/src/services/heartbeat.ts:3155+`, Cap `DEFAULT_MAX_LIVENESS_CONTINUATION_ATTEMPTS=2` wird umgangen)
- CoS (38f933cd): 848 Runs, 785 automation, **8 % useful-action-rate** (schlechtester Wert)
- CEO (7795b4b0): 1.000 Runs seit 2026-05-01, 805 automation, 644 needs_followup, 14 % useful-action-rate
- Token-Controller: 1.000 Runs in 12 h (~80/h), `spentMonthlyCents=0` für alle Agents → kann seinen eigenen Job gar nicht erfüllen
- QUA-671: 2.069 WAIT_GUARD-JSONs in `docs/ops/`, ein Polling alle ~40 s, Issue ist *logisch* OWNER-blocked aber Status `in_progress`
- Meta:Work-Commit-Ratio = **313:1** seit 2026-05-05 (450/754 Commits sind QUA-Loop-Ops, 78 WAIT_GUARD, 76 Liveness-Pings, 21 Snapshot-Refreshes; nur 2 echte Pipeline-Code-Changes — beide derselbe Commit auf zwei Branches)
- P3-Param-Sweep: 130 Runs in 1.549 min, median Inter-Arrival 193 s, kein Delta < 10 s. **5-fach parallel würde ~82 min ergeben → Faktor 19 zu langsam**
- Slash-Command `.claude/commands/p3-launch.md:26` sagt wörtlich *"P3 uses terminal=any — sequential, 1 terminal at a time. This is expected."* — das wurde nach QUA-901 nicht aktualisiert

Detailliertes Audit-Material: `C:/QM/repo/.audit/agents.json`, `.audit/per_agent/`, `.audit/issues.json` (Subagent-Output, noch nicht in `docs/ops/` migriert).

---

## P1 — DL-046-Enforcement: QUA-671 stoppen (CEO direkt, ~10 min)

QUA-671 (P0-13 T6 deploy-manifest dry-run signoff) ist *logisch* blocked auf OWNER, aber Status `in_progress`. PowerShell-Polling füllt die Lücke und produziert 2.069 WAIT_GUARD-JSONs. Direkter DL-046-Verstoß.

CEO macht direkt:
1. `PATCH http://127.0.0.1:3100/api/issues/{QUA-671-uuid}` mit `{"status":"blocked","blockedReason":"awaiting OWNER P0-13 manifest review — see comment thread for durable record"}`
2. Comment vorher posten mit Begründung + Verweis auf das durable record (memory feedback_paperclip_api_blockedreason_no_persistence: Spalte hat keine DB-Persistenz, Comment ist die echte Quelle)
3. Optional: child issue `assigneeUserId="local-board"` für den OWNER-Signoff erstellen, in `blockedByIssueIds` von QUA-671 einhängen
4. CEO weist DevOps an: `scripts/ops/qua671_wait_guard.ps1` aus den 5 nicht-eigenen Worktrees stoppen (Audit-Subagent fand das Skript in 6 Worktrees gleichzeitig — nur 1 sollte laufen, idealerweise gar keiner bis OWNER-Signoff)

Acceptance: GET QUA-671 zeigt `status=blocked`, kein neuer WAIT_GUARD-File seit dem Cutoff in `docs/ops/`.

## P2 — Heartbeat-Disable für Idle-Agenten (CEO direkt, ~10 min)

Drei Agents wurden von CEO selbst angeworben → CEO hat PATCH-Scope (memory feedback_paperclip_agent_config_patch_works). **`enabled=false` ≠ pause** — kein OWNER-Gate.

Targets:
- **Token-Controller-2** (`acf5d16b`): ist Duplikat von Token-Controller. → `PATCH /api/agents/acf5d16b...` body `{"runtimeConfig":{"heartbeat":{"enabled":false}}}`
- **Gmail-Monitor** (`6dcf0a42`): Phase Final ist DEFERRED (memory project_qm_comms_gmail_requirement). Agent feuert für eine Phase die nicht angefangen hat. → enabled=false
- **Controlling-Agent** (`a790f129`): Hire ist DEFERRED per `docs/ops/QM-00064_CONTROLLING_HIRE_DEFER_2026-05-05.md`. → enabled=false
- **Token-Controller** (`bd089fcb`): Cron `0 */2 * * *` → cron auf 4-stündlich oder enabled=false bis Budgets gewired sind (siehe P9). Aktuell findet er nichts (alle agents 0¢) und committet trotzdem. → `runtimeConfig.heartbeatCron="0 */6 * * *"` ODER enabled=false

PATCH-Beispiel (curl, loopback ohne Bearer in local_trusted): Body via temp-file mit `--data-binary @body.json`, body.json enthält `{"runtimeConfig":{"heartbeat":{"enabled":false}}}`. Direkt-inline mit `-d` und Quote-Escapes funktioniert auch, aber temp-file ist robuster. Endpoint: `PATCH /api/agents/{agent_id}` (Content-Type application/json).

Acceptance: GET /api/agents zeigt für alle 4 entweder enabled=false oder cron-stretch; nächste 24 h zeigen 0 automation-Runs für diese 4 in `/api/heartbeat-runs`.

## P3 — CEO + CoS auf assignment-only (CEO direkt für sich selbst, ~5 min)

CEO Self-PATCH: `PATCH /api/agents/7795b4b0-...` body `{"runtimeConfig":{"heartbeat":{"enabled":false,"wakeOnDemand":true}}}`. CEO bleibt produktiv über (a) das tägliche 06:00 UTC Routine-Wake (`5db99de9-...`), (b) assignment-Wakes wenn neue Issues an CEO zugewiesen werden, (c) issue-comment-Wakes auf eigenen Issues.

Begründung: Im Audit sind 805/1.000 CEO-Runs `automation` mit 64 % `needs_followup`. CEO ist der teuerste Agent (Opus 4.7, ~$616/7 d). Die meisten Auto-Wakes finden nichts zu tun, weil PHASE_STATE.md selten innerhalb einer 3 h-Periode meaningful ändert.

CoS analog: `PATCH /api/agents/38f933cd-...` mit demselben Body. CoS hat 8 % useful-action-rate.

Wenn CEO unsicher ist, ob er sein eigenes Heartbeat abschalten darf — Selbst-PATCH ist explizit erlaubt (memory feedback_paperclip_agent_config_patch_works: "CoS can only PATCH itself" → CEO erst recht).

Acceptance: 24 h nach PATCH zeigt `/api/heartbeat-runs?agentId=7795b4b0-...` nur noch `routine`/`assignment`/`comment`-getriggerte Runs, keine `automation` mehr.

---

## P4 — P3-Parallelität reparieren (CEO → CTO `241ccf3c`, diese Woche)

**Direkt phase-3-blockierend.** QUA-902 (P3 FAIL Triage auf QM5_1003) wartet aktuell auf eine Run-Pipeline die 19× zu langsam ist.

Root-Cause: Dispatch-Key-Mismatch zwischen äußerer Reservation und innerem Re-Resolve.

- `framework/scripts/p3_param_sweep.py:117-125` reserviert mit `phase="P3", version="p3_sweep", max_per_terminal=1`
- `framework/scripts/run_smoke.ps1:125-133` (innen aufgerufen) re-resolved mit hardcoded `phase="P1", version="smoke", max_per_terminal=3`

Resultat: zwei verschiedene Dedup-Buckets in `D:/QM/Reports/pipeline/dispatch_state.json`. Terminal-Accounting inkohärent. In der Praxis serialisiert auf das Terminal das `resolve_target_terminal` zuerst zurückgibt.

Patch (CTO):
1. `run_smoke.ps1:125-133`: zwei optionale Params `-DispatchPhase` und `-DispatchVersion` hinzufügen, default behält bisheriges Verhalten
2. `p3_param_sweep.py:88-104`: ruft `run_smoke.ps1` mit `-DispatchPhase P3 -DispatchVersion p3_sweep` auf
3. `.claude/commands/p3-launch.md:26`: Lüge entfernen ("sequential, 1 terminal at a time"). Neuer Text: *"P3 dispatcht bis zu 5 parallele Terminals; Wall-Time sollte ~1/5 des seriellen Falls sein. Verifiziere via mtime-Spread in `D:/QM/reports/pipeline/<EA>/P3/QM5_*/`."*
4. Bonus im selben Diff: `framework/scripts/p5_stress_driver.py:64,121-147` und `p6_multiseed_driver.py:110-126` haben dieselbe Krankheit (blockierendes `subprocess.run` statt `Popen`-Pool). Beide auf das Pattern aus `p2_matrix_launcher.py:130-139` umstellen (`DETACHED_PROCESS` Popen, Round-Robin über T1..T5).

Acceptance: P3-Sweep für QM5_1003 schließt in < 2 h Wall-Time (Baseline 25,8 h). Verifizieren via mtime-Spread.

## P5 — EA-Source-Dirs aufräumen (CEO → DevOps `86015301`, diese Woche)

`framework/EAs/QM5_1003_davey_baseline_3bar/` enthält ~20 Files `QUA-649_*.{md,json,signal,csv}` zwischen `.mq5/.ex5/.set`. Codex globbt das Verzeichnis bei jedem Edit — Kontext-Verschmutzung.

DevOps:
1. `git mv framework/EAs/*/QUA-* docs/ops/QUA-archived/` (oder analoge Struktur)
2. `.gitignore`-Regel: `framework/EAs/*/QUA-*` und `framework/EAs/*/*.signal`
3. CI-Lint-Hook (optional): pre-commit hook der QUA-* in framework/EAs/ rejected

Acceptance: `find framework/EAs -name "QUA-*"` ist leer. EA-Source-Dirs enthalten nur `.mq5/.mqh/.ex5/.set/.json`-Karten und Run-Outputs.

Erwarteter Effekt: 20–40 % Codex-Kontext-Reduktion pro EA-Edit.

---

## P6 — CEO-Sweep nach Python migrieren (CEO → CTO, 2–3 Wochen)

**Höchster Token-Hebel im System** weil CEO-Heartbeats die teuersten sind.

Aktuell: CEO-`HEARTBEAT.md:5-30` schickt das LLM durch 3 Schleifen die rein deterministischen Status-Check + Age-Vergleich + Routing-Tabelle abarbeiten — das ist Python-Arbeit, kein Reasoning.

Build:
- `paperclip/tools/ops/ceo_queue_sweep.py` (~250 LOC)
- Aktionen: GET in_review-Liste, Backlog-Triage, Stale-Detection, Status-Cross-Check
- Mutiert Paperclip via curl-API (in_review → done bei eindeutigen Closeout-Mustern, Backlog-Dispatch nach Routing-Tabelle aus CEO-AGENTS.md)
- Output: JSON `{decisions: [...], escalations: [...]}`
- CEO-LLM bekommt nur `escalations[]` (Erfahrungswert: 0–2 pro Wake) plus `decisions[]` als Audit-Trail
- HEARTBEAT.md wird umgeschrieben: erste Aktion ist `python paperclip/tools/ops/ceo_queue_sweep.py`, danach reagiert CEO nur auf `escalations[]`

Erwartete Einsparung: ~60 % CEO-Token-Spend.

## P7 — Process-Adapter für deterministische Skills (CEO → CTO, 2–3 Wochen)

**Der eigentliche "mehr Python, weniger AI"-Hebel.**

Paperclip hat einen 86-LOC pure-Shell-Adapter (`app/server/src/adapters/process/execute.ts`) der genau dafür gedacht ist: Skill-Body läuft als Subprocess mit Env-Vars `PAPERCLIP_API_URL/AGENT_ID/RUN_ID/TASK_ID/WAKE_REASON`, idle-Heartbeat kostet ~0 Tokens. Spec: `app/doc/SPEC-implementation.md:571-584` und `app/doc/GOAL.md:46-49` (*"Heartbeat loop — simple custom Python that loops, checks in, does work"* — Paperclips eigener Originalintent).

Skills die heute LLM-Adapter laufen aber pure deterministisch sind:
- `qm-token-monitor` (skill body GET /agents → diff baseline → write JSON; kein Reasoning)
- `Invoke-DwxHourlyCheck.ps1` (PowerShell)
- `kanban_archive_daily` (CSV-Rotation per DL-060)
- Notion→Git nightly mirror (manifest-driven)
- `dl054_gate_runner.py` ist schon deterministisch (return verdict an Z. 106-115)
- WAIT_GUARD-Polling falls überhaupt nötig nach P1

CTO baut: für jeden dieser Skills `PATCH /api/agents/{id}` mit `adapterType: "process"` und `adapterConfig.command/args/cwd`. Bei Issue-Assignment springt der Process-Adapter; LLM-Adapter wird nur bei expliziten Wake-Reasons (Mention, Eskalation) hochgefahren — via custom Plugin-Adapter (`app/adapter-plugin.md`) als `qm-process-or-llm`-Variante.

Acceptance: mindestens 3 Skills laufen produktiv auf process-Adapter; `heartbeat-runs` für diese Agents zeigt `outcome=completed` ohne LLM-Cost.

---

## P8 — Continuation-Cap-Bug (CEO eskaliert an OWNER, lokaler Paperclip-Patch)

`app/server/src/services/heartbeat.ts:3155+` hat mehrere Call-Sites die `retryOfRunId` setzen ohne `continuationAttempt` zu inkrementieren. Folge: 770/774 DevOps-Retries haben `continuationAttempt=0` und umgehen den Cap `DEFAULT_MAX_LIVENESS_CONTINUATION_ATTEMPTS=2`. Das produziert die ~19.500 DevOps-Runs/Tag (statt 48).

Fix lokal in `C:/QM/paperclip/app/.git`, **kein Upstream-Push** (memory project_qm_paperclip_app_patch_policy: OWNER 2026-05-05 hat das so entschieden).

CEO erstellt CTO/Development-Issue mit klarem Patch-Plan. Wenn das nicht innerhalb von 1 Woche landet, eskaliert CEO an Board Advisor (Class-2) zur direkten Intervention.

Erwartete Einsparung: DevOps von ~19.500 → 48 Runs/Tag (–99,8 %).

## P9 — Budget-Hard-Stops + Codex-Cost-Ingest (CEO eskaliert an OWNER)

Aktuell `spentMonthlyCents=0` für alle 22 Agents (memory cos_token_baseline). `app/server/src/services/budgets.ts:716-862` ist verdrahtet, aber keine Policy gesetzt.

Eskalation an OWNER: `PATCH /api/companies/{id}/budgets` für Anthropic-Tier-Agents (CEO/Research/Doc-KM/CoS/Quality-*) mit `hardStopEnabled=true`. Codex-Spend extrahieren aus `data/instances/default/companies/<id>/codex-home/state_5.sqlite` und via `POST /companies/{id}/cost-events` einspeisen (Spec: `app/doc/SPEC-implementation.md:530, 681-695`).

Effekt: Token-Controller wird vom Polling- zum Reaktiv-Agenten (Threshold-Breach-getriggert), und das System hat einen echten Cost-Ceiling statt einer Polling-Heuristik.

---

## Leitprinzipien

- **KEINE Pause-API-Calls** für P1–P3. Alle CEO-Aktionen sind config-PATCHes (`runtimeConfig.heartbeat.*`). Pause/Resume bleiben OWNER-Class (memory feedback_agent_pause_unpause_owner_only).
- **DL-046 strikt**: keine "still blocked"-Comments oder WAIT_GUARD-Polling auf blocked Issues. Comment-thread ist durable record.
- **Comment-then-PATCH** bei Status-Änderungen (memory feedback_in_review_needs_closeout_comment): erst Begründung als Comment, dann Status-PATCH — sonst feuert next heartbeat re-fire auf das ursprüngliche Assignment.
- **Forward slashes in Comments** (memory feedback_paperclip_api_backslash_comment_500): `D:/QM/...` statt `D:\\QM\\...`, sonst HTTP 500.
- **Loopback bypassed bearer** in local_trusted (memory reference_paperclip_local_trusted_api): `curl http://127.0.0.1:3100/api/...` ohne Token funktioniert für alle Mutationen.
- **Filesystem > Vault > Notion** (CLAUDE.md Source-Of-Truth-Order).

## Pfade

- Audit-Daten: `C:/QM/repo/.audit/agents.json`, `.audit/per_agent/`, `.audit/issues.json`
- Paperclip-Source: `C:/QM/paperclip/app/server/src/services/heartbeat.ts:3155`, `routines.ts`, `run-liveness.ts:62-77`, `adapters/process/execute.ts`
- Framework: `C:/QM/repo/framework/scripts/p3_param_sweep.py`, `run_smoke.ps1`, `p5_stress_driver.py`, `p6_multiseed_driver.py`, `p2_matrix_launcher.py` (Vorbild)
- Slash-Commands: `C:/QM/repo/.claude/commands/p3-launch.md:26`
- CEO-Heartbeat: `C:/QM/paperclip/data/instances/default/companies/03d4dcc8-.../agents/7795b4b0-.../instructions/HEARTBEAT.md:5-30`
- Skill-Body Token-Monitor: `C:/QM/worktrees/chief-of-staff/skills/qm/qm-token-monitor/SKILL.md`

## Sequenzierung & Acceptance

| Punkt | Wer | Wann | Acceptance |
|---|---|---|---|
| P1 | CEO direkt | heute | QUA-671 status=blocked + child issue, kein neuer WAIT_GUARD seit Cutoff |
| P2 | CEO direkt | heute | 4 Agents config-PATCHed, 24 h später 0 automation-Runs |
| P3 | CEO direkt (Self-PATCH + CoS) | heute | CEO + CoS heartbeat.enabled=false |
| P4 | CEO → CTO | diese Woche | P3-Sweep < 2 h Wall-Time (statt 25,8 h) |
| P5 | CEO → DevOps | diese Woche | EA-Source-Dirs frei von QUA-* |
| P6 | CEO → CTO | 2–3 Wochen | ceo_queue_sweep.py merged, HEARTBEAT.md refactored |
| P7 | CEO → CTO | 2–3 Wochen | ≥3 Skills auf process-Adapter |
| P8 | CEO → OWNER (Class-2) | 1 Woche | continuation-cap Bug gefixt, DevOps Runs < 100/Tag |
| P9 | CEO → OWNER (Class-2) | parallel | Budget hard-stops aktiv, Codex-cost-events ingestiert |

CEO darf P1–P3 **ohne OWNER-Confirmation** durchziehen. P4–P5 sind Code-Changes — CEO erstellt Issues und dispatcht. P8–P9 muss CEO an OWNER eskalieren weil sie Code-Patch (P8) bzw. Cost-Policy (P9) sind.

Wenn ein Punkt blockiert: Comment auf dieses Parent-Issue mit Begründung + Eskalations-Pfad, NICHT in Schleife retryen.

Geschätzter Gesamteffekt: ~60–80 % Reduktion Anthropic-Token-Spend, ~99 % Reduktion DevOps-Run-Volumen, P3 19× schneller, EA-Edits 20–40 % weniger Codex-Kontext.
