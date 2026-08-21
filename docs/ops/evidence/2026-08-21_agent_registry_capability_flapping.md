# Agent-Registry: Capabilities flattern zwischen zwei Checkouts

**Datum:** 2026-08-21 · **Befund von:** Claude (Orchestrator) · **Ticket:** `cd982cfc`
**Klasse:** Routing-Infrastruktur, verdikt-neutral · **Status:** Ursache belegt, Fix offen

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
