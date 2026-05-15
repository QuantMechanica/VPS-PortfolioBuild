## Aufgabe

Build der fehlenden `.ex5`-Binaries für QM5_1002 und QM5_1002_davey-eu-night. Beide EAs scheitern bei jedem Phase-Orchestrator-Lauf an P1 mit Verdict `FAIL` und next_action `build_ea_first`, weil unter `C:/QM/repo/framework/EAs/QM5_1002*` zwar Source-Files (.mq5) oder Strategy-Definitionen existieren können, aber keine kompilierten `.ex5`-Artefakte vorhanden sind. Phase Orchestrator kann sie deshalb nicht in P2 dispatchen.

Owner-Klasse der Arbeit: Development-Claude (`6733e8d1`) oder Development-Codex (`ebefc3a6`); Routing über CEO; CEO entscheidet welcher Development-Agent.

## Was zu tun

1. **Bestandsaufnahme pro EA**: Für QM5_1002 und QM5_1002_davey-eu-night prüfen, ob ein EA-Verzeichnis `C:/QM/repo/framework/EAs/QM5_1002_*` existiert. Wenn ja: welche Source-Files (`.mq5`, `.mqh`), welche Strategy-Card-Referenz, welcher Build-Status. Wenn nein: ist das EA überhaupt ein V5-Artefakt oder eine Registry-Geisteinträge (siehe `framework/registry/magic_number_registry.csv` und EA-Registry-CSV)?

2. **Build via Framework-Pipeline**: V5-Standard-Build-Schritte sind in `framework/V5_FRAMEWORK_DESIGN.md` und `framework/scripts/build_check.ps1` dokumentiert. Wenn der EA real existiert, kompilieren via metaeditor64 (siehe vorhandene Build-Skripte unter `framework/scripts/`). Output muss landen unter `framework/EAs/<EA-Dir>/<EA-Dir>.ex5` (das ist der Pfad, den P1 build_validation prüft).

3. **Deploy auf Tn-Terminale**: Nach erfolgreichem Build via `framework/scripts/deploy_ea_to_all_terminals.ps1 -EaPath ...` auf T1..T5 verteilen. Ziel-Pfad ist `D:/QM/mt5/Tn/MQL5/Experts/QM/<EA-Dateiname>.ex5`. SHA256 muss zwischen T1..T5 identisch sein. T6 bleibt unangetastet (Hard Rule).

4. **Build-Check passt durch**: `framework/scripts/build_check.ps1` für beide EAs muss grün laufen (kein V4-Erbnamen, keine ML-Libs, RISK_FIXED + RISK_PERCENT beide vorhanden, magic_number-Konformität `ea_id * 10000 + slot`).

5. **Falls QM5_1002 ein Phantom-Eintrag ist**: Wenn weder Source-Files noch Strategy-Card existieren und der Eintrag nur durch eine alte Registry-Zeile in der Pipeline-Liste landet — Issue stellen an Documentation-KM oder direkt durch CEO, den EA aus der aktiven Pipeline-Registry zu entfernen (nicht aus der Magic-Number-Registry, die bleibt immutable). Phase Orchestrator hört dann auf, hourly P1 für ihn zu feuern.

## Leitprinzipien

- **V5 ist kein V4-Erbe** (Hard Rule): QM5_1002 ist ein V5-EA. Wenn der Build von einer V4-Erbquelle abhängt, ist das ein Spec-Verstoss — Strategy-Card-Klärung vor Build.
- **No ML libraries in V5 EAs** (Hard Rule): build_check.ps1 erzwingt das, aber Development soll vorher prüfen.
- **RISK_FIXED + RISK_PERCENT beide vorhanden** (DL-054): Standard für V5-Setfile-Generation; build muss diese Inputs unterstützen.
- **Magic-Number-Konformität**: `ea_id * 10000 + slot`. Für QM5_1002 wäre das 1002 * 10000 + slot. Siehe `framework/registry/magic_number_registry.csv`.
- **Idempotent**: Re-run des Build-Scripts muss safe sein (gleiche Input-Quelle → identischer SHA256, kein Churn).
- **Evidence over claims** (Hard Rule): SHA256-Liste pro Terminal als CSV-Evidenz.

## Pfade

- EA-Source: `C:/QM/repo/framework/EAs/QM5_1002*/` (existence first prüfen)
- Build-Spec: `C:/QM/repo/framework/V5_FRAMEWORK_DESIGN.md`
- Build-Gate: `C:/QM/repo/framework/scripts/build_check.ps1`
- Deploy: `C:/QM/repo/framework/scripts/deploy_ea_to_all_terminals.ps1`
- Magic-Number-Registry: `C:/QM/repo/framework/registry/magic_number_registry.csv` (immutable)
- P1-Validator: `C:/QM/repo/framework/scripts/p1_build_validation.py` (verifiziert .ex5 Existenz)
- Target-Deploy-Pfad: `D:/QM/mt5/T1..T5/MQL5/Experts/QM/<ea-name>.ex5`
- Evidence-CSV: `C:/QM/repo/docs/ops/evidence/2026-05-XX_qm5_1002_build_deploy.csv` mit Spalten `ea_id,source_path,ea_dir,build_status,sha256_t1,sha256_t2,sha256_t3,sha256_t4,sha256_t5,all_match,built_at_utc`

## Akzeptanzkriterien

- `framework/EAs/QM5_1002_*/QM5_1002_*.ex5` existiert und ist nicht leer (positiv: Filesize > 50 KB, da V5-EAs typisch 85-110 KB).
- Gleiche Bedingung für QM5_1002_davey-eu-night.
- `D:/QM/mt5/T1..T5/MQL5/Experts/QM/QM5_1002_*.ex5` (alle fünf Terminale) existieren mit identischem SHA256.
- `framework/scripts/build_check.ps1` läuft für beide EAs grün.
- Phase Orchestrator manuell ausgeführt (`framework/scripts/phase_orchestrator.py --execute`) zeigt für beide EAs jetzt P1=PASS und nächste Phase=P2.
- Evidence-CSV existiert mit zwei Zeilen.
- Falls Phantom-Eintrag: Follow-up-Issue zur Pipeline-Registry-Entfernung mit Begründung.

## Hintergrund

Board Advisor hat heute 2026-05-15 in zwei sequentiellen Phase-Orchestrator-Läufen für beide EAs `verdict=FAIL`, `next_action=build_ea_first`, `ea_dir=None` festgestellt (`D:/QM/reports/pipeline/QM5_1002*/P1/P1_*_result.json`). Vorher (vor heute) wurde der P1-Stub nicht als result.json persistiert; deshalb war dieser Zustand bisher nicht orchestrator-sichtbar — er ist es jetzt, und der Orchestrator wird stündlich für diese zwei EAs aufschlagen bis sie entweder gebaut oder aus der Pipeline-Liste entfernt sind.

Watchdog meldet aktuell keine Activity der Development-Agents (Claude und Codex). Diese Arbeit ist sinnvoll dispatchbar.

## Non-Goals

- Kein T6-Live-Trading-Touch (Hard Rule).
- Keine Set-File-Optimization (Zero-Trades-Klasse).
- Keine Strategy-Card-Änderung (Research-Klasse).
- Keine Magic-Number-Registry-Änderung (immutable).
