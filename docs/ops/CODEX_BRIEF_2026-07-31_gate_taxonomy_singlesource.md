# CODEX BRIEF — Gate-Taxonomie Single-Source (Spec-Review R1, bei >=90 % direkt implementieren)

**Ticket-Klasse:** ops_issue · **Autor der Spec:** Claude · **Reviewer:** Codex (du)
**Protokoll:** Adversarialer Review dieser Spec. Nenne im Verdikt eine explizite
**Zustimmungs-Prozentzahl**. `>= 90 %` -> implementiere im selben Ticket (Spec +
deine akzeptierten Amendments). `< 90 %` -> REVIEW mit Findings, Runde 2 folgt.
Die Implementierung wird danach von Claude erneut reviewt (Ledger:
`docs/ops/CONVERGENCE_LEDGER_WEEKEND_2026-07-31.md`, Topic A).

## Befund (Claude-Audit 2026-07-31, file:line verifiziert)

Kanonisch: `tools/strategy_farm/config/gate_manifest.v1.json` = **14 Gates
Q00–Q13**, kollabierte `legacy_aliases` (P3.5→Q03, P4→Q04, P5/P5b/P5c→Q05,
P6→Q07, P7/P8→Q08, P9→Q11, P9b→Q12, P10→Q13). Identisch mit
`tools/strategy_farm/phase_ids.py` `LEGACY_P_TO_Q` (Zeilen 74-90) — beide OHNE Q14.

Defekte:
1. **`render_cockpit.py` nutzt phase_ids NICHT**, sondern eine eigene lokale
   `PHASE_DISPLAY`-Karte (Zeilen 93-115), deren P-Key-Hälfte die **stale
   Offset-Karte** ist (P4→Q05, P5c→Q08, P7→Q10, P8→Q11 …). Genutzt an :758
   (Frontier-Tile) und :1815 (Phasen-Bucket). Latent: jede Legacy-P-Zeile würde
   falsch gelabelt und widerspräche strategies.html (das korrekt
   `phase_label`/`LEGACY_P_TO_Q` importiert). Der Kommentar :2462 behauptet
   fälschlich phase_ids-Nutzung.
2. `render_cockpit.py:2463-2464` `Q_DISPLAY_ORDER = ["Q01"…"Q13"]` — **Q00
   fehlt** im Fortschrittsstreifen. `:2471-2473` `_q_with_legacy` paart Q-IDs mit
   den FALSCHEN Legacy-Keys (Q08↔P5c, Q10↔P7 …) für die Zähl-UNION.
3. **Stale `Q14`** lebt in `tools/strategy_farm/farmctl.py:3343`
   (`"Q14": "P10"` in `PHASE_NOMENCLATURE`, Offset-Karte Zeilen 3326-3344,
   konsumiert von `_normalize_phase` :3347) und in
   `framework/registry/state_name_adapter.json:259` (`"P10": "Q14"`) sowie
   `:152` (`LIVE_DEPLOYED.display_phase = "Q14"`); dessen ganzer
   `phase_display_id`-Block (244-260) + eingebettete `display_phase`-Werte
   folgen dem stale Offset-Schema.
4. `gate_manifest.py` wird von **keinem** Runtime-Modul importiert (nur vom
   eigenen Test) — der „refuse Q14"-Guard ist nicht tragend.

## Spec (Soll-Zustand)

1. **Cockpit auf phase_ids:** lokale `PHASE_DISPLAY` (93-115) und
   `_q_with_legacy` (2471-2473) ersetzen durch Imports aus `phase_ids`
   (`phase_label`, `LEGACY_P_TO_Q`, invertierte Zuordnung wo nötig).
   `Q_DISPLAY_ORDER` aus dem Manifest ableiten — **Q00 enthalten**. Kommentar
   :2462 korrigieren.
2. **farmctl:** `"Q14"`-Eintrag entfernen; `PHASE_NOMENCLATURE` aus den
   Manifest-Aliases bzw. `phase_ids` ableiten statt hart kodieren. **Vorher
   Call-Site-Audit von `_normalize_phase`:** falls irgendein Pfad damit
   Storage-Keys SCHREIBT (DB, public-data-Snapshots), muss der Storage-Pfad eine
   eingefrorene Kompatibilitätskarte behalten — kanonisch wird nur die ANZEIGE.
   Kollabierte Aliases sind nicht 1:1 invertierbar (Q05←P5/P5b/P5c, Q08←P7/P8):
   primären Alias dokumentiert wählen (Vorschlag: erster Eintrag der
   Manifest-Alias-Liste).
3. **state_name_adapter.json:** Q14-Einträge (:152, :259) entfernen;
   `phase_display_id` + eingebettete `display_phase`-Werte auf die kollabierte
   kanonische Karte ziehen. **Vorher Konsumenten-Grep** (framework/ + tools/):
   wer liest diese Registry, und ist irgendein Leser storage- statt
   display-seitig?
4. **Manifest verdrahten:** `phase_ids.py` validiert seine Tabellen beim Import
   gegen `gate_manifest.v1.json` via `gate_manifest.py`-Loader und wirft bei
   Abweichung (fail-closed). Damit ist das Manifest Single-Source, ohne heiße
   Pfade auf JSON-Parsing umzustellen.
5. **Tests:** bestehende `test_gate_manifest.py` erweitern: (a) phase_ids ==
   Manifest, (b) render_cockpit nutzt keine lokale Karte mehr (Import-Check),
   (c) Render-Smoke: cockpit.html enthält `Q00` und kein `Q14`, beide Dashboards
   labeln jeden Legacy-P-Key identisch.
6. **Verifikation:** beide Renderer einmal laufen lassen
   (`render_cockpit.py`, `dashboards/render_dashboards.py`), gerenderte HTML
   auf Q00-Präsenz/Q14-Absenz greppen, Zähler je Phase vor/nach identisch
   (aktuelle DB ist rein kanonisch — jede Zählabweichung ist ein Fehler).

## Randbedingungen

- Anzeige-Flächen zeigen NUR Qxx (stehende OWNER-Regel). Storage-/public-data-
  Kompatibilitätskeys (`P*`) werden NICHT umgeschrieben.
- Keine Gate-Logik-, DB- oder Task-Änderung; reine Darstellungs-/Mapping-Arbeit.
- Factory läuft: kein Factory_OFF/ON, Dashboards-Render ist read-only gegenüber
  der DB und darf laufen.
- Commits mit expliziten Pathspecs; Tests grün als Laufnachweis im Deliverable.

## Deliverable

`docs/ops/evidence/2026-07-31_gate_taxonomy_singlesource.md`: Zustimmungs-%,
Findings, (bei >=90 %) Implementierungs-Commits + Testlauf-Summary +
Render-Grep-Beweis. Danach `update-task <id> --state REVIEW --artifact-path
<deliverable> --verdict "<kurz>"`.
