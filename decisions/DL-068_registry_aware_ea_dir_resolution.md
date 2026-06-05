# DL-068 — Registry-Aware EA-Dir Resolution (systemic ea_dir_ambiguous fix)

**Date:** 2026-06-05
**Status:** Decided (OWNER + Claude) — ausgeliefert auf agents/board-advisor + origin/main
**Supersedes:** none — härtet die `_preferred_ea_dir`-Heuristik + ergänzt DL-062
**Related:** DL-062 (v2 ea_dir_ambiguous), `project_qm_v2_ea_dir_ambiguous_2026-05-25`, `tools/strategy_farm/farmctl.py` (`_preferred_ea_dir`, `_registered_ea_slug`), `terminal_worker.py`, `repair.py`, `framework/scripts/p2_baseline.py` + `p3_param_sweep.py`, `magic_numbers.csv`

## Kontext

98 EAs haben mehrere On-Disk-Dirs (`<ea>_slug` + `<ea>_slug_v2`, Drittvarianten, oder
Slug-Format-Dupes wie `davey-baseline-3bar` vs `davey_baseline_3bar`). Die Phasen-Runner
(`terminal_worker.py`, `farmctl` dispatch, `repair.py`, `p2_baseline.py`, `p3_param_sweep.py`)
warfen bei >1 Kandidat hart `ea_dir_ambiguous` → invalider Run → 0 Trades. Ein Backfill
am 2026-06-03 maskierte eine ganze Q08-Welle so als „FAIL" (Diagnose: forensisch belegt,
EAs liefen legitim bis Q07 PASS). DL-062 hatte das als „OWNER picks fix path" offen gelassen.

## Entscheidung

**Die in `magic_numbers.csv` registrierte `ea_slug` ist die Quelle der Wahrheit für das
kanonische Dir.** Bei mehreren Kandidaten wählt der Resolver deterministisch das Dir, dessen
Slug registriert ist; erst wenn die Registry keinen eindeutigen Treffer liefert, Fallback auf
die eindeutige höchste Version; sonst (echte Mehrdeutigkeit) weiterhin Fehler.

Umsetzung: `_preferred_ea_dir` (farmctl) registry-aware gemacht (+ neuer `_registered_ea_slug`);
alle ambiguous-werfenden Stellen leiten jetzt durch diese Logik (farmctl dispatch, terminal_worker,
repair, + eigenständige `_registered_ea_slug`/`find_ea_dir` in den beiden framework-Scripts).

## Warum nicht „prefer highest version (v2)"

Verifiziert über alle 98: registry-aware löst **98/98** auf — und **93 davon wählen v1 statt
eines vorhandenen v2**. Die alte Heuristik „höchste Version" hätte also 93 EAs auf die
unregistrierten v2-Orphans (u.a. die fehlerhaften Gemini-News-Bypass-Reworks vom 06-02)
geroutet. Die Registry ist authoritativ und richtungsagnostisch — sie kann v1, v2 oder eine
bestimmte Slug-Schreibweise benennen.

## Wichtiger Implementierungs-Hinweis

`_registered_ea_slug` MUSS die EA-Nummer via `QM5_(\d+)` extrahieren, NICHT `(\d+)` — letzteres
greift die „5" in „QM5" (dokumentiert auch in `_portfolio_admission_key`). Dieser Bug ließ den
ersten Wurf still auf 0 Registry-Treffer fallen.

## Risiko

Praktisch null: die 98 ambiguous EAs scheiterten zuvor ohnehin (`ea_dir_ambiguous` → invalid).
Der Fix kann nur verbessern (Fehler → läuft den registrierten Build). Downstream-Gates +
Build-Guardrails bleiben das Sicherheitsnetz.

## Revert-Bedingung

Falls ein registriertes Slug je auf ein fehlerhaftes Build-Dir zeigt: das ist dann ein
Registry-Daten-Fehler (magic_numbers.csv), nicht ein Resolver-Fehler — dort korrigieren, nicht
die Resolver-Policy aufweichen.
