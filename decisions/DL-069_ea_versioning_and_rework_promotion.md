# DL-069 — EA Versioning & Rework Promotion (v1/v2/v3…) via the Registry

**Date:** 2026-06-05
**Status:** Decided (OWNER + Claude) — ausgeliefert auf agents/board-advisor + origin/main
**Supersedes:** none — verallgemeinert DL-068 (registry-aware resolution) auf beliebige Versionen + definiert den Rework-Promotion-Flow
**Related:** DL-068, DL-062, `tools/strategy_farm/farmctl.py` (`_active_registered_slugs`, `_preferred_ea_dir`), `terminal_worker.py`, `repair.py`, `framework/scripts/p2_baseline.py` + `p3_param_sweep.py`, `tools/strategy_farm/health.py` (`chk_stranded_ea_improvements`), `magic_numbers.csv`

## Problem (von OWNER aufgedeckt)

DL-068 wählte das Dir, dessen Slug registriert ist. Aber: wenn ein EA verbessert wird
(z.B. Zero-Trade-Fix) und als `_v2` geliefert wird, blieb die v1-Registrierung bestehen →
der Resolver nahm weiter v1, die Verbesserung versandete. Und es kann genauso v3, v4 … geben.

## Entscheidung (die Regel)

**Die Registry (`magic_numbers.csv`) ist der Promotion-Schalter. Der Resolver wählt die
HÖCHSTE aktiv-registrierte Version unter den On-Disk-Dirs.**

- `_active_registered_slugs(ea_id)` = alle Slugs mit nicht-`retired` Registry-Zeile.
- `_preferred_ea_dir`: unter den Kandidaten-Dirs die aktiv-registrierten nehmen, davon die
  höchste `_vN`; wenn keiner registriert ist, Fallback auf die eindeutige höchste Version;
  sonst None (echt mehrdeutig).
- Generalisiert auf v1/v2/v3/…: eine Verbesserung **gewinnt automatisch, sobald sie
  registriert ist** — kein Hardcoding, kein manuelles „retire v1" nötig (höhere aktive
  Version schlägt niedrigere). Unregistrierte `_vN`-Dirs werden ignoriert.

Verifiziert: 98/98 mehrdeutige EAs lösen auf; 1086/1087/1088 (v1+v2 beide aktiv) nehmen jetzt
korrekt **v2** (die Verbesserung) statt v1.

## Rework-Flow (verbindlich)

Eine EA-Verbesserung kommt in die Pipeline auf genau einem dieser Wege:
1. **In-place rebuild (Default):** denselben Slug behalten, `{ea}_{slug}` überschreiben
   (der normale Build schreibt ohnehin dorthin), dann **ab Q02 neu enqueuen**. Git behält die
   Historie. Resolver nimmt es automatisch.
2. **Neue Version `_vN`:** Dir `{ea}_{slug}_vN` anlegen UND den `_vN`-Slug **aktiv in
   `magic_numbers.csv` registrieren** (`ea_id*10000+slot`, eigener Slot-Block). Resolver nimmt
   dann die höchste aktive Version. Optional die alte Version auf `status=retired` setzen.

**Niemals** ein `_vN`-Dir ohne Registrierung liegen lassen — es ist dann ein inerter Orphan
(genau das verursachte den DL-062/Q08-Stau).

## Guard

`health.chk_stranded_ea_improvements` flaggt EAs mit einem höher-versionierten Dir, das NICHT
aktiv-registriert ist (= gebaut, aber nicht promotet). Beim Einbau: **90 EAs** geflaggt — diese
brauchen pro-EA-Entscheidung: registrieren (echte Verbesserung) oder Orphan entfernen. Der
Resolver fährt derweil sicher den registrierten Build.

## Wichtiger Implementierungs-Hinweis

EA-Nummer via `QM5_(\d+)` extrahieren, NICHT `(\d+)` (greift die „5" in „QM5").
