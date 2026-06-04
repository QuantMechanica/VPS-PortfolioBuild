# DL-067 — Single-Run P2/Q02 Full Backtest (2-Run-Determinismus-Check entfernt)

**Date:** 2026-06-04
**Status:** Decided (OWNER + Claude) — ausgeliefert auf agents/board-advisor + origin/main
**Supersedes:** none — modifiziert die `full_run.runs`-Regel aus DL-038 / `tester_defaults.json` (2 → 1)
**Related:** DL-038 (Seven Binding Backtest Rules), DL-054 (anti-theater pass criteria), `framework/registry/tester_defaults.json`, `tools/strategy_farm/farmctl.py` (`_dispatch_work_item` n_runs), `project_qm_fleet_scaling_t11_t14_2026-06-04` (8-Kern-Durchsatz-Decke), `project_qm_p2_backtest_policy_2026-05-22`

## Kontext

Der MT5-Backtest-Durchsatz ist der bindende Engpass der Factory: ~5.400 pending
work_items auf einer VPS mit **8 physischen Kernen** (Tick-Backtests sind ~1-Thread
CPU-bound). Mehr Terminals lösen das nicht (bei 10 schon überbucht — siehe
T11-T14-Analyse). Die zwei realen Durchsatz-Hebel ohne Hardware-Upgrade:
Defender-Exclusions (umgesetzt 2026-06-04) und die **Per-Backtest-Kosten**.

Der dominante Kostenposten ist der kanonische P2/Q02-Full-Run: 6-Jahres-Fenster
(2017–2022), real-tick Model 4 — und bisher **2 Läufe** je EA/Symbol. Die zwei
Läufe waren ein **Determinismus-Check** (gleiche Inputs → gleiches Ergebnis), kein
Mittelwert/keine Monte-Carlo-Robustheit.

## Entscheidung

`full_run.runs` für **P2/Q02-Full-Runs** von **2 → 1** reduzieren.

Begründung: Model-4 real-tick MT5 ist für ein **unverändertes `.ex5` deterministisch**.
Der zweite identische Lauf liefert (außer bei einem echten Non-Determinismus-Bug)
dasselbe Ergebnis — er ist near-redundant. Die Exploration-Kinder (ablation/grid/
synth) liefen ohnehin schon mit 1 Lauf ohne Probleme; dieser Pfad ist also erprobt.
Effekt: **~Halbierung der dominanten Queue-Kosten.**

**Scope (bewusst eng):** nur der **P2/Q02-Full-Run**. Prescreen war schon 1 Lauf;
Exploration war schon 1 Lauf; **Q03/Q04 behalten ihre bisherige Lauf-Zahl** (nicht
analysiert, nicht angefasst).

## Trade-off / Risiko

Der Determinismus-Check entfällt für den kanonischen P2/Q02-Run. Ein EA mit echter
Non-Determinismus-Quelle (uninitialisierter State, Zeit-/Seed-Abhängigkeit, die
durch die Framework-Corset eigentlich verboten ist) würde nicht mehr durch zwei
divergierende Läufe auffallen. Bewertung: geringes Risiko, weil (a) die V5-Framework-
Corset solche Quellen ohnehin verbietet, (b) Model-4 deterministisch ist, (c) der
Exploration-Pfad mit 1 Lauf seit Wochen ohne Determinismus-Vorfall läuft.

## Umsetzung

- `tools/strategy_farm/farmctl.py`: im P2/Q02-Full-Branch `n_runs = "1"` (vorher "2"
  aus dem gemeinsamen Default). Exploration/Prescreen unverändert (waren schon 1).
- `framework/registry/tester_defaults.json`: `p2_real_tick_policy.full_run.runs` 2→1
  + `runs_note`; `version` 1→2; `_authority` um DL-067 ergänzt.

## Revert-Bedingung

Zurück auf `runs: 2`, sobald ein Non-Determinismus-Verdacht für einen P2-EA auftaucht
(zwei Läufe desselben `.ex5` würden divergieren). Dann ist der Determinismus-Re-Check
die billigste Diagnose und wird wieder bindend.
