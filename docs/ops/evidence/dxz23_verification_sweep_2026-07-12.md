# DXZ-23 Verifikations-Sweep — Befunde (2026-07-12/13)

OWNER-Mandat: „Ich möchte, dass du eine saubere Datenlage hast, vl entdeckst du was,
das uns bisher verborgen blieb?" — vor dem 15→23-Sleeve-Deploy alle Buch-EAs frisch
backtesten und gegen die Referenz-Streams (Basis der Gewichte + KPIs) verifizieren.
Ergebnis: 4 systemische Entdeckungen, 2 davon farmweit.

## Endergebnis (Runde 3, echte Frisch-Builds, Full-History 2017–2025, Model 4)

**18/23 Sleeves reproduzieren ihre Referenz AUF DEN CENT** (z.B. 10513/XAU: 76 Trades /
$9.649,32 exakt). 13128/NDX: Trades exakt (56), Net in bekannter NDX-Tick-Varianz.
11165/AUDCAD: frisch 207 = exakt der Manifest-Wert (die „Referenz" 133 war ein
Stale-Stream — Hazard-Klasse). 12778: Basket, separater Langlauf. 1556 + 10706: siehe
Phantom-Build-Befund. Rohdaten: `D:/QM/reports/portfolio/book23_verify_sweep_20260712/`
(sweep_result.json, sweep_progress.jsonl, sweep_run.log).

## Entdeckung 1 (FARMWEIT KRITISCH): MetaEditor-No-Op-Compiles

`metaeditor64 /compile:` **überspringt den Build still, wenn die Ziel-.ex5 existiert**
— Include-mtimes werden nicht geprüft; die .ex5-mtime wird angefasst und PASS gemeldet.
Beweis: Hash vor/nach „Recompile" identisch (be91ab89…); nach **Löschen + Compile**
neuer Hash (13001747…, +38KB Zwei-Pass-q08-Code). Konsequenz: **jede
Framework-Fix-Rollout-Direktive („alle EAs neu kompilieren") war für EAs ohne
.mq5-Änderung ein farmweiter No-Op** — u.a. q08-SL/TP-Fix (07-10) und
KillSwitch-Halt-Fix (07-05) erreichten die Repo-Binaries nie.
**Fix:** compile_one.ps1 löscht die Ziel-.ex5 jetzt vor dem Aufruf (Commit `abd2b1847`).
Alle 20 Buch-Binaries echt neu gebaut + atomar committet (`cf2264bb0`).

## Entdeckung 2: Phantom-Builds — Qualifikations-Evidenz ohne committeten Code

Die 07-11-Requalifikation von 1556/10706 lief auf Binaries, deren Quellstand nie in git
lag (Repair-Commit `924b78842` enthielt nur .mq5, nie .ex5; No-Op-Compiles hielten die
alten Blobs am Leben). Stream-Diff frisch vs Phantom:
- **1556/XAU:** Referenz ⊂ Frisch, exakt **11 fehlende Monats-Entries 2024-11–2025-10**
  (mitten in der Gold-Rally; Delta +$1.720 zugunsten frisch). **Das Phantom hatte das
  Entry-Loch — der committete Build ist der korrektere.**
- **10706/GBP:** 362 gemeinsame Trades auf den Cent identisch ($61.210); nur 5/2
  Boundary-Trades unterschiedlich (3 große Referenz-Runner = Net-Differenz).
**Konsequenz:** Q08/Q09-Evidenz vom 07-11 für beide ungültig (gehört zu Phantom-Code) →
echte Requalifikation der committeten Builds gestartet (`D:/QM/reports/requal_20260713/`).
**Klassen-Lektion: .mq5-Commit ≠ deploybare Binary. Build + Commit atomar; Qualifikation
zählt nur auf committetem Stand.**

## Entdeckung 3: Factory-Automation setzt unkommittete .ex5 zurück

Um 00:00 wurden die (noch unkommitteten) Frisch-Builds auf HEAD zurückgesetzt
(Dirty-Guard/Pump-Restore-Klasse; Codex-Lane war aktiv — 13205-Commits). Uncommitted
Binaries überleben auf dem Canonical-Checkout keine Nacht → Build+Commit im selben Skript.

## Entdeckung 4: MT5 `/config:` schneidet Forward-Slash-Pfade ab

`terminal64 /config:D:/pfad/x.ini` startet als **normale, konto-verbundene Instanz**
(Config „D:\" — Startup-Zeile prüfen!). Meine ersten Treiber erzeugten so 3
Live-Konto-verbundene Streuner-Terminals (pfadverankert gekillt, T_Live/FTMO unberührt).
Backslash-Pfade zwingend; `initialized from start config` im Journal verifizieren.
Folgeklasse: nach Hard-Kill von Streunern halten deren Agents kurz Datei-Handles →
`'SYM' file opening or reading error [32]` beim nächsten Start (Retry/Stagger nötig).

## Nebenbefunde

- **Friday-Close ist de-facto Buch-Policy:** Live-Presets setzen `qm_friday_close_enabled`
  nicht → Default true überall. 1556 (Karte: „weeks to months" Hold) exitet dadurch 100%
  freitags, Median-Hold 4,8d — policy-konform, aber die Karte wird faktisch zu einem
  Wochen-Timer. Bewusst so qualifiziert; als Karten-Realitäts-Gap dokumentiert.
- Factory-Terminals loggen sich beim Start ins Live-Konto ein (OWNER 07-12: by design ok).
- News-Kalender byte-stabil seit Mai (als Drift-Verdächtiger ausgeschlossen).
- `QM_NewBook_LiveVsBook_Sunday` Task-Fail 07-12 06:00Z (0x1, Log endet nach START) — offen.
