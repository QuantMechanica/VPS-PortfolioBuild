## Aufgabe

Diagnose und Behebung des durchgängigen P2-Baseline-Versagens für fünf EAs (QM5_1003, QM5_1004, QM5_1014, QM5_1017, QM5_SRC04_S03). Alle fünf zeigen das gleiche Muster: 0 PASS pro P2-Lauf, dominierende Reject-Reason `run_smoke_fail:MIN_TRADES_NOT_MET`. Die EAs handeln zu wenig (oder gar nicht) gegen den DXZ-Tickdaten-Baseline. Phase Orchestrator markiert sie deshalb BLOCKED at P2 und das Phase-Wave kommt nicht weiter.

Owner-Klasse der Arbeit: Zero-Trades-Specialist (`8ba981d2`); Routing über CEO.

## Was zu tun

1. **Pro EA Reproduktion mit minimalem Trade-Threshold**: Aus dem letzten `report.csv` jedes EA jeweils eine Symbol/Period-Kombi auswählen, bei der run_smoke `MIN_TRADES_NOT_MET` gemeldet hat (vorzugsweise eine, bei der das Backtest tatsächlich ausgeführt wurde, nicht `no_summary_json:rc=1`). Den existierenden `.set` aus `framework/EAs/<EA>/sets/` heranziehen und in MT5 Strategy Tester manuell ausführen (oder per run_smoke einzeln) — bestätigen, dass das Ergebnis reproduzierbar ist.

2. **Trade-Anzahl gegen Mission-Baseline**: Pro EA dokumentieren, wie viele Trades pro Jahr generiert werden gegenüber der DL-054 Anti-Theater Mindestgrenze (siehe `paperclip/governance/PHASE_STATE.md` und `framework/V5_FRAMEWORK_DESIGN.md` für die aktuelle MIN_TRADES Konfiguration in `tester_defaults.json`).

3. **Strategy-Card-Bezug**: Aus `paperclip/data/strategy_cards/` die Karte des jeweiligen EA lesen — die ursprüngliche Strategy-Hypothese mit dem tatsächlichen Trade-Verhalten abgleichen. Wenn die Hypothese ein anderes Setup-Frequenz-Niveau impliziert, ist das ein Strategy-Card-Drift; wenn die Hypothese korrekt ist und der EA-Code zu wenig handelt, ist das ein EA-Code-Drift.

4. **Set-File-Recalibration (falls zulässig)**: Wenn ein einzelner Parameter (z. B. Trigger-Threshold, Lookback-Period) im sub_gate-zulässigen Bereich nachjustiert werden kann und das die Trade-Frequenz auf MIN_TRADES bringt — neuen `.set` über `framework/scripts/gen_setfile.ps1` erzeugen, P2 erneut dispatchen. Keine Black-Box-Optimization, keine Curve-Fitting-Loops.

5. **Eskalation falls Strategy-/EA-Drift**: Wenn der EA-Code geändert werden muss (nicht nur Set-File) — Eskalation an Development-Claude/Development-Codex über separates Issue. Wenn die Strategy-Card-Hypothese revidiert werden muss — Eskalation an V5-Strategy-Research über Issue.

6. **Pro EA Verdict**: Pro EA eine von vier Entscheidungen liefern und in CSV festhalten:
   - `RECALIBRATED` — neuer `.set` erzeugt, P2 erneut gefahren, jetzt PASS
   - `STRATEGY_DRIFT` — Strategy-Card stimmt nicht mit EA-Code überein, Eskalation an Research/Dev gestellt
   - `EA_CODE_DRIFT` — EA-Code-Bug, Eskalation an Development gestellt
   - `BASELINE_ACCURATE_FAILED` — EA handelt korrekt gemäß Strategy-Card, aber die Strategie als Hypothese ist tot → EA-Pipeline-Abbruch und Aufnahme in `paperclip/governance/lessons_learned.md`

## Leitprinzipien

- **Evidence over claims** (Hard Rule): Pro EA-Verdict zwingend ein report.csv-Pfad oder summary.json-Pfad als Beleg.
- **No new ML libraries in V5 EAs** (Hard Rule): Diese Arbeit darf keine sklearn/xgboost/torch-Importe in EA-Code einführen.
- **RISK_FIXED bleibt bei $1000 für Backtest** (DL-054 / framework/registry/tester_defaults.json) — diese Arbeit ändert keine Risk-Mode-Konfiguration.
- **Keine sub_gate-Parameter erfinden**: Erlaubte Parameterbereiche stehen in den jeweiligen `framework/EAs/<EA>/strategy.md` oder Strategy-Card. Wenn ein Parameter ausserhalb dieses Bereichs liegt, ist das `STRATEGY_DRIFT`, nicht `RECALIBRATED`.
- **Reproduzierbar**: Jede neue P2-Dispatch muss mit dem dedup-Key `ea_id|version|symbol|phase|sub_gate_config_hash` in `D:/QM/reports/pipeline/dispatch_state.json` landen.
- **No mocks**: Trade-Counts kommen aus echten MT5-Tester-Reports, nie aus geschätzten oder synthetisch erzeugten Datensätzen.

## Pfade

- EA-Verzeichnisse: `C:/QM/repo/framework/EAs/QM5_1003_davey_baseline_3bar/`, `.../QM5_1004_davey_es_breakout/`, `.../QM5_1014_lien_channels/`, `.../QM5_1017_chan_pairs_stat_arb/`, `.../QM5_SRC04_S03_lien_fade_double_zeros/`
- Aktuelle P2-Resultate: `D:/QM/reports/pipeline/<EA>/P2/p2_<EA>_result.json` und `D:/QM/reports/pipeline/<EA>/P2/report.csv`
- Tester-Defaults: `C:/QM/repo/framework/registry/tester_defaults.json`
- Strategy-Cards: `C:/QM/paperclip/data/strategy_cards/`
- Set-File-Generator: `C:/QM/repo/framework/scripts/gen_setfile.ps1`
- Phase-Orchestrator: `C:/QM/repo/framework/scripts/phase_orchestrator.py` (hourly via Windows Task `QM_Phase_Orchestrator`)
- Evidence-CSV (Pflicht): `C:/QM/repo/docs/ops/evidence/2026-05-XX_zero_trades_p2_baseline_verdicts.csv` mit Spalten `ea_id,symbol,period,trade_count,min_trades_required,verdict,evidence_path,decided_at_utc`

## Akzeptanzkriterien

- Pro EA ein Verdict (`RECALIBRATED` / `STRATEGY_DRIFT` / `EA_CODE_DRIFT` / `BASELINE_ACCURATE_FAILED`) mit Evidenz-Pfad.
- Evidence-CSV existiert und enthält fünf Zeilen, eine pro EA, mit allen Spalten gefüllt.
- Für jeden `RECALIBRATED`-Verdict ist im `dispatch_state.json` mindestens ein neuer P2-Eintrag mit `verdict=PASS` für mindestens ein Symbol vorhanden.
- Für jeden `STRATEGY_DRIFT`- oder `EA_CODE_DRIFT`-Verdict ist ein Follow-up-Issue an Research bzw. Development existent (Issue-ID im Evidence-CSV referenziert).
- Watchdog `pipeline_health/latest.json` zeigt `runs_last_2h > 0` für Zero-Trades-Specialist `8ba981d2`.

## Hintergrund

Board Advisor hat heute 2026-05-15 die Infrastructure-Layer-Probleme behoben (Phase-Orchestrator-Scheduled-Task auf S4U umgestellt, HoP-Heartbeat-Loop durch Pausieren der saturation-scheduler-Routine 93af0c1f gestoppt, Squatting-Terminals beendet, P1-Stub schreibt jetzt result.json). Die fünf BLOCKED EAs sind danach das verbleibende EA-Layer-Problem: kein Infra-Bug mehr, sondern echtes Strategy-/Trade-Frequency-Problem.

Watchdog meldet Zero-Trades-Specialist (`8ba981d2`) seit über 2h idle. Diese Arbeit ist genau das, wofür dieser Sub-Agent existiert.

## Non-Goals

- Kein T6-Live-Trading-Touch (Hard Rule).
- Keine neuen EAs schreiben (Development-Klasse).
- Keine Änderung an `framework/registry/tester_defaults.json` ohne separate Board-Approval (DL-054).
- Kein Aggregator/Orchestrator-Code-Change (CTO-Klasse).
