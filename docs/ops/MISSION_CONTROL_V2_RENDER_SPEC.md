# Mission Control v2 — Render-Spezifikation (Shadow-Phase)

**Autor:** Claude (Design-Lane, Orchestrator) · **Datum:** 2026-08-21
**Programm:** `12 ToDo/03_Mission_Control_Cockpit` · **Datenvertrag:** `docs/ops/MISSION_CONTROL_V2_DATA_CONTRACT.md` (`qm.mission_control.v2`)
**Ziel-Datei:** `D:\QM\strategy_farm\dashboards\cockpit_v2.html` — parallel zum alten Cockpit (Shadow-Betrieb, Umsetzungsschritt 4). `cockpit.html` bleibt unangetastet, bis OWNER abnimmt.

## Leitidee

Die Seite beantwortet die fünf Steuerungsfragen in < 30 Sekunden, von oben nach unten
in fallender Dringlichkeit: *Läuft es? → Was muss ICH entscheiden? → Was wurde geschafft?
→ Woran arbeiten die Terminals? → Wo ist der Engpass? → Was ist mit den Daten los?*
Alles andere ist Drill-down-Link, kein zweiter Zahlenblock.

## Architektur

- **Renderer:** `tools/strategy_farm/render_cockpit_v2.py`. Importiert den Contract-Builder
  aus `mission_control_v2_data.py` und baut den Vertrag frisch bei Renderzeit
  (Single Source of Truth). Fallback-Flag `--from-json <path>` liest den Preview-Snapshot;
  in dem Fall trägt der Header ein STALE-Badge mit dem Snapshot-Alter.
- **Read-only absolut:** keinerlei Aktions-Elemente (Abnahmekriterium: keine Cockpit-Aktion
  kann Factory/Deploy/AutoTrading verändern). Owner-Decisions verlinken nur auf Evidenz.
- **CSS:** `<link rel="stylesheet" href="style.css">` (liegt im selben Verzeichnis) +
  ein kleiner seitenspezifischer `<style>`-Block NUR für Grid-Layouts dieser Seite.
  Ausschließlich `var(--*)`-Tokens; keine neuen Farben. Disziplin gilt hart:
  `border-radius:0`, kein Glow/Gradient/Blur/Motion, Hairline-Borders.
- **JS:** maximal ein kleines Inline-Script für Relativzeit-Anzeige ("vor 3 min") und
  Collapse der Sekundärsektionen. Keine externen Libraries, keine Charts in der Shadow-Phase.
- **Gate-Namen:** ausschließlich Qxx über die Contract-Felder (`phase_qid`/`phase_name`).
  Ein Test beweist: kein `P[0-9]`-Token im gerenderten HTML.

## Sektionen (Reihenfolge = Seitenreihenfolge)

### 1 · Kontrollstreifen (sticky, eine Zeile, 6 Zellen)
`control_strip` →
- **Factory**: Anzeige-Mapping nach der ratifizierten Regel (feedback 2026-06-x):
  ROT/CRITICAL **nur** wenn die Factory wirklich steht (OFF-Flag ohne Maintenance-Kontext
  oder keinerlei laufende Claims); `FACTORY_OFF.flag` ⇒ MAINTENANCE (amber);
  Health-FAIL bei laufender Factory ⇒ DEGRADED (amber). Der Emitter-Rohzustand und
  `factory_state_reason` werden IMMER als Subzeile gezeigt — das Mapping versteckt nichts,
  es priorisiert nur die Ampel. Mapping-Logik im Renderer, mit Unit-Test aller vier Fälle.
- **Freshness**: ältestes kritisches Readmodel + Alter; `any_stale` ⇒ amber Badge STALE.
- **Queue**: `pending_executable` groß, daneben klein `+parked` und `active` (keine Doppelzählung; Summe ausgewiesen).
- **Terminals**: `running/fleet` groß, `reserved`/`idle` klein.
- **Clear-ETA**: P50 in Tagen+Stunden, P90 als Band dahinter ("~11,5 T · P90 19,1 T"), Tooltip/`title` = `eta_to_empty.basis` wörtlich.
- **OWNER**: offene Entscheidungen, davon Alert-Anzahl rot, älteste Wartezeit.

### 2 · Owner Decision Queue
`owner_decisions.items` — nur wenn `count > 0`. Max. **5** Zeilen, danach "… n weitere"
(Link auf Drill-down/Vault OWNER.md). Zeile: Severity-Chip · ID · Frage (eine Zeile,
ellipsis) · Empfehlung (kursiv, `--text-2`) · Cost-of-Wait · Alter. Keine Buttons.
Reine Agent-Queues erscheinen hier nie (garantiert der Emitter; Renderer testet Feld nur durch).

### 3 · Fortschrittsvergleich
`progress` — EINE Tabelle, Spalten **Heute · Gestern · 7-Tage-Ø · Gesamt**, Zeilen:
erledigte Work Items · eindeutige EA/Symbol-Paare · Gate PASS · wirtschaftliche FAIL ·
Infra/Transient-Quote (%). Zahlen in JetBrains Mono, rechtsbündig. Infra-Zeile gedimmt
(`--text-3`) — Infra ist nie Merit. „Gesamt" trägt sichtbar `since` + die `caveats`
als Fußnote (klein, `--text-4`). `counting_basis` wörtlich als Fußzeile.

### 4 · Terminal Board T1–T10
`terminals.terminals` — **immer alle 10**, festes Grid 5×2 (≥1200px) / 2-spaltig darunter.
Karte: Terminal-ID groß mono · Zustands-Chip (RUNNING = `--signal`, RESERVED = `--promising`,
IDLE = `--dead` + Grund, ERROR = `--fail`) · EA `QM5_xxxxx` + Slug · Symbol · Gate
`Qxx · Name` · Start UTC + elapsed (Relativzeit) · Work-Item-Kurz-ID (Link auf EA-Detailseite
`ea_<id>.html` falls vorhanden, sonst plain). Idle-Karten zeigen den Idle-/Reservierungsgrund
statt leerer Felder.

### 5 · Queue & Engpass
`queue` — Tabelle `by_phase_executable` (Gate Qxx · Anzahl · ältester Eintrag), darunter
getrennt und klar beschriftet `by_phase_parked` („operator-gated — zählt nicht in die ETA").
Engpass-Zeile: Phase mit größtem Bestand + `notes` wörtlich. ETA-Block wiederholt P50/P90
mit Basis-Satz (kein Schein-Determinismus).

### 6 · Ausnahmen & Datenqualität
Alle `meta.degraded_reason ≠ null` als rote Hairline-Boxen; alle `staleness=STALE`-Sektionen
gelistet; `progress.caveats`; `health_fail_count` mit Hinweis „Detail: farmctl health /
Heartbeat". Diese Sektion ist collapsible, default offen wenn nicht leer.

### Fußzeile
`generated_at` · `schema_version` · Quelle-DB · Renderdauer · „SHADOW — Referenz bleibt
cockpit.html bis zur OWNER-Abnahme".

## Nicht auf dieser Seite (Drill-down bleibt im alten Cockpit)
Q00–Q16-Chipleiste über Epochen, Contract-Kohorten-Matrix, Q14–Q16-Programmtexte,
Scheduled-Task-Heartbeats, Live-/FTMO-Narrative, agentische Aktivitätszähler.

## Tests (pytest, Fixture-Contract-JSON)
1. Alle 10 Terminals gerendert, Idle mit Grund.
2. Kein `P[0-9]`-Gate-Token im HTML (Regex über sichtbaren Text).
3. Factory-Ampel-Mapping: 4 Fälle (ON, OFF-Flag→MAINTENANCE, Health-FAIL+laufend→DEGRADED, wirklich down→CRITICAL).
4. Decision-Queue cappt bei 5 + „n weitere".
5. STALE-Badge erscheint bei `staleness=STALE` und bei `--from-json`.
6. Kein `<button>`/`<form>`/`onclick`-Aktionselement im Dokument.
7. Queue-Summen: angezeigte Teilmengen addieren zur Gesamtsumme.

## Abnahme (aus dem Programm, hier verbindlich)
Owner sieht jede offene Entscheidung + Cost of Wait ohne Logsuche; alle zehn Terminals
zeigen EA/Symbol/Gate/Laufzeit oder expliziten Grund; einheitliche Zähllogik sichtbar;
Queue-Summe nachvollziehbar; Stale sichtbar im selben Renderzyklus; keine Aktionspfade.
