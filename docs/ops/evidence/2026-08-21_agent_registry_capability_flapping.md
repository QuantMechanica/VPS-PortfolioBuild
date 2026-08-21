# Agent-Registry: Capabilities flattern zwischen zwei Checkouts

**Datum:** 2026-08-21 · **Befund von:** Claude (Orchestrator) · **Ticket:** `cd982cfc`
**Klasse:** Routing-Infrastruktur, verdikt-neutral · **Status:** Ursache belegt,
Fix behoben in Commit `9c8f5ab8e` (siehe Abschnitt „Fix umgesetzt" unten und
Schwester-Dok `2026-08-21_router_registry_authority_repair.md`)

## Kurzfassung

Die Tabelle `agent_registry` wird von **mehreren Checkouts desselben Codes** geschrieben, die
unterschiedliche `DEFAULT_AGENT_REGISTRY`-Stände tragen. `sync_default_registry`
(`tools/strategy_farm/agent_router.py:320-357`) macht ein bedingungsloses
`ON CONFLICT DO UPDATE SET capabilities_json=excluded.capabilities_json` — wer zuletzt läuft,
gewinnt. Ergebnis: die Fähigkeiten der Agenten **wechseln im Minutentakt** zwischen einem
breiten und einem schmalen Satz.

Das ist kein einmaliger Drift, den man einmal geradezieht. Es ist ein Zustand, der sich nach
jeder Korrektur von selbst wiederherstellt.

## Messung

Beobachtet am 2026-08-21 innerhalb von fünf Minuten, dieselbe Datenbank
(`D:/QM/strategy_farm/state/farm_state.sqlite`):

| Zeitpunkt (UTC) | `claude` capabilities | `gemini` capabilities |
|---|---|---|
| 12:48:25 | `code, research, review, strategy, summary` | `research, strategy, source_discovery` |
| 12:53:40 | `code, tests, repo_edit, repo, ops, research, review, strategy, summary` | `code, tests, repo_edit, research, strategy, source_discovery, video_analysis` |

Die Quelle der beiden Stände, direkt aus den Arbeitskopien gelesen:

| Checkout | `claude` | `gemini` |
|---|---|---|
| `C:/QM/repo` (kanonisch, `agents/board-advisor`) | **breit** (mit `ops`, `repo`, `tests`, `repo_edit`) | **breit** (mit `video_analysis`) |
| `C:/QM/worktrees/codex-orchestration-1` | **schmal** (ohne `ops`) | **schmal** (ohne `video_analysis`) |
| `C:/QM/worktrees/gemini-orchestration-1` | **schmal** (ohne `ops`) | **schmal** (ohne `video_analysis`) |

Der breite Stand stammt aus Commit `ccca6cf13` *„ops(lanes): claude lane full coding caps +
Sonnet 5 headless (OWNER 2026-07-03)"*. Die beiden Orchestrierungs-Worktrees stehen davor.

## Warum das weh tut

Routing prüft `required.issubset(capabilities)` (`agent_router.py:588`). Maßgeblich sind:

```
TASK_TYPE_CAPABILITIES["ops_issue"]      = ["ops", "code"]
TASK_TYPE_CAPABILITIES["triage_failure"] = ["ops", "review"]
```

**In jedem schmalen Fenster gilt:**

1. **Die Claude-Lane kann keinen einzigen `ops_issue` oder `triage_failure` annehmen** — ihr
   fehlt `ops`. Alle Ops-Tickets sind dann strukturell codex-only. Das kehrt genau die
   OWNER-Entscheidung vom 2026-07-02/03 um, die im Code-Kommentar über der Deklaration steht
   („headless Sonnet lane takes coding tasks incl. former codex work; Codex weekly quota is the
   scarce one"). Es ist ein plausibler Mitverursacher dafür, dass Codex bei ~130 % Wochenpace
   läuft, während Claude Luft hat.
2. **Antigravity kann keine Video-Analyse annehmen** — `video_analysis` fehlt. Das ist die
   *einzige* Aufgabe, die nur agy kann (VPS-IP ist auf YouTube bot-blockiert). Ein Video-Ticket
   in einem schmalen Fenster wartet, statt zu laufen.

Beides ist unsichtbar: eine nicht routbare Aufgabe wird übersprungen und sieht in jeder
Oberfläche aus wie normaler Rückstau.

## Was hier ausdrücklich **nicht** die Antwort ist

`sync_default_registry` flottenweit laufen zu lassen. Es würde die `gemini`-Lane in
`["code","tests","repo_edit"]` verbreitern und damit den Research-Sitz für Coding-Arbeit
öffnen — unerwünscht: die agy-Bauwelle vom 2026-08-21 ergab 49 von 50 negativen Reviews über
sechs wiederkehrende Defektklassen. Die breite `gemini`-Deklaration im kanonischen Checkout
ist selbst fragwürdig und gehört mitgeprüft, nicht mitgezogen.

## Empfohlene Richtung

1. **Eine schreibende Instanz.** Nur der kanonische Checkout darf `agent_registry` schreiben;
   Orchestrierungs-Worktrees synchronisieren nicht mehr, sondern lesen.
2. **Fail-loud statt still.** Ein Test, der prüft, dass die Live-Registry für jede Lane eine
   Obermenge dessen deklariert, was `TASK_TYPE_CAPABILITIES` von ihr verlangt — plus eine
   Warnung, wenn eine Aufgabe wegen fehlender Capability übersprungen wird, statt sie stumm
   zu überspringen.
3. **`gemini`-Capabilities getrennt entscheiden.** `video_analysis` gehört hinein.
   `code`/`tests`/`repo_edit` gehören auf den Prüfstand, nicht automatisch mit.

Punkt 3 berührt die Arbeitsteilung der Agenten und ist damit eine Entscheidung, keine
Reparatur — sie wird vorgelegt, nicht autonom gezogen.

## Reproduktion

```powershell
cd C:/QM/repo
python -c "import sqlite3;c=sqlite3.connect(r'D:/QM/strategy_farm/state/farm_state.sqlite');c.row_factory=sqlite3.Row;[print(r['agent_id'],r['updated_at'],r['capabilities_json']) for r in c.execute('select * from agent_registry')]"
```

Zweimal im Abstand von ~10 Minuten ausführen und die Zeilen vergleichen.

---

## Fix umgesetzt (2026-08-21, ticket cd982cfc, Commit `9c8f5ab8e`)

Betroffene Dateien: `tools/strategy_farm/agent_router.py`,
`tools/strategy_farm/tests/test_agent_router.py` (beide in `9c8f5ab8e`),
`docs/ops/evidence/2026-08-21_router_registry_authority_repair.md`
(Rollback-SQL + Init-Beleg) und dieses Root-Cause-Dokument.

### Teil 1 — genau ein schreibender Checkout

`sync_default_registry` schreibt nur noch, wenn der ausführende Checkout ein
*primärer* Checkout ist. Gate: `_registry_writer_authorized()` prüft
`(ROUTER_CHECKOUT_ROOT / ".git").is_dir()`, wobei
`ROUTER_CHECKOUT_ROOT = Path(__file__).resolve().parents[2]`. Ein normaler
Checkout (`C:/QM/repo`) hat ein `.git`-**Verzeichnis** → schreibberechtigt. Ein
Git-Linked-Worktree (die Orchestrierungs-Worktrees) hat eine `.git`-**Datei** →
nicht berechtigt, kehrt read-only zurück (`{"synced":[], "read_only":true,
"reason":"linked_worktree_registry_reader"}`) und liest nur die Contract-Lage.
Das deckt automatisch alle sechs Aufrufstellen von `sync_default_registry` ab
(`route_once`, `route_many`→`route_once`, `replenish`, `run_once`, `status`,
`enqueue_friday_smoke_tasks`), da alle durch dieselbe Funktion laufen. Der
kanonische Schreiber ist der 5-Minuten-Task `QM_StrategyFarm_AgentRouter_5min`
(`run_agent_router_task.py`, hartkodiert `REPO_ROOT=C:\QM\repo`, importiert
`tools.strategy_farm.agent_router` aus dem kanonischen Baum → `.git`-Verzeichnis
→ schreibt den kanonischen Stand). Die Orchestrierungs-Worktrees rufen
`agent_router.py` aus ihrem eigenen (linked) Checkout auf und können die Zeilen
nicht mehr überschreiben.

### Teil 2 — Superset-Test

Neuer Test `test_default_and_live_registry_cover_each_lane_contract`
(`tests/test_agent_router.py`). Er prüft für jede Lane in
`AGENT_TASK_TYPE_LANES` (codex/claude → `ops_issue`,`triage_failure`; gemini →
`research_strategy`) plus `AGENT_EXTRA_REQUIRED_CAPABILITIES`
(gemini → `video_analysis`), dass die deklarierten Capabilities eine **Obermenge**
der geforderten sind — sowohl im `DEFAULT_AGENT_REGISTRY` als auch in der per
`sync_default_registry` geschriebenen Live-Registry (`registry_contract`). Ein
zweiter Test `test_linked_worktree_is_registry_reader_and_cannot_overwrite_rows`
belegt, dass ein Linked-Worktree eine zuvor eingeschmuggelte schmale
`claude`-Zeile NICHT überschreibt (read-only) und der Contract die Lücke meldet.
Ergebnis (2026-08-21, aus `C:/QM/repo`):

```
python -m pytest tools/strategy_farm/tests/test_agent_router.py -q
27 passed in 70.13s
```

Gegen das heutige „schmal gewinnt"-Szenario (claude ohne `ops`) meldet
`registry_contract(...)["ok"]==False` mit
`gaps=[{agent_id:"claude", missing:["ops"], ...}]`.

### Teil 3 — fail-loud statt stiller Skip

`route_once` prüft vor der Agentenauswahl `_capability_profile_gap(conn, required)`:
existiert KEIN Agent, dessen Capabilities die geforderten enthalten, dann
- persistiert `_record_capability_warning` eine sichtbare Warnung in
  `payload_json.router_capability_warning` (`code=ROUTER_CAPABILITY_UNROUTABLE`,
  `required`, `missing_by_agent`) UND ein Event `routing_capability_unroutable`,
  ohne Queue-Alter/Priorität zu ändern;
- die `RouteDecision.reason` wird `capability_unavailable:<caps>` statt des
  generischen `no_available_agent`.
Sichtbar zusätzlich in `agent_router.py status` über das Feld
`registry_contract` (Lücken pro Lane), das die Orchestrierungs-Prompt jeden
Zyklus ausführt und das Dashboards/Menschen lesen. So sieht man „N Tasks haben
keinen fähigen Agenten" statt gewöhnlichen Rückstaus.

### Scope-Korrektur (gemini bleibt unverändert)

Ein zuvor uncommitteter Arbeitsstand hatte `gemini` im `DEFAULT_AGENT_REGISTRY`
**verschmälert** (`code`,`tests`,`repo_edit` entfernt). Das verletzt die
Ticket-Vorgabe („gemini-Set exakt wie im kanonischen Repo lassen; die
gemini-Frage ist eine separate OWNER-Entscheidung, nicht Teil dieses Fixes")
und brach drei Bestandstests (build_ea routete auf codex statt gemini, die
Review-Dispatch-Gate greift nur bei gemini-Builds). Korrigiert: `gemini` steht
wieder auf dem kanonischen Satz
`["code","tests","repo_edit","research","strategy","source_discovery","video_analysis"]`.
Die Entscheidung, ob `code`/`tests`/`repo_edit` auf der Research/Video-Lane
bleiben, ist weiterhin OWNER-Vorlage (siehe Abschnitt „Empfohlene Richtung" Pkt 3).

## Rollback-Record (Live-Stand bei Fix-Beginn, 2026-08-21 ~13:18Z)

Falls der Fix rückgängig gemacht werden muss, sind dies die exakten
`capabilities_json`-Werte, wie sie bei Beginn in
`D:/QM/strategy_farm/state/agent_registry` standen (kanonischer/breiter Stand,
der zu diesem Zeitpunkt gerade gewonnen hatte):

| agent_id | enabled | max_parallel | cost_rank | capabilities_json |
|---|---|---|---|---|
| claude | 1 | 3 | 30 | `["code","tests","repo_edit","repo","ops","research","review","strategy","summary"]` |
| codex  | 1 | 5 | 20 | `["code","tests","repo_edit","review","ops","research","strategy"]` |
| gemini | 1 | 2 | 10 | `["code","tests","repo_edit","research","strategy","source_discovery","video_analysis"]` |

`cost_rank` und `max_parallel` wurden vom Fix NICHT verändert (nur Eligibility /
Schreib-Gate). Rückabwicklung: die drei Zeilen mit obigen Werten neu schreiben
und den `_registry_writer_authorized`-Gate in `sync_default_registry` entfernen.
