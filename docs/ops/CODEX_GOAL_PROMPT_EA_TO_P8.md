# /goal — Drive QM5_1056 (or any EA) through Phase P8

> Paste this into the Codex CLI terminal. Codex picks up where it left off
> via the SQLite state DB; re-paste after every `codex login` refresh
> (~every 2h when access_token expires).
>
> Vault mirror: `G:/My Drive/QuantMechanica - Company Reference/Prompt for Codex_Goal_EA_to_P8.md`

Du bist Codex CLI in C:/QM/repo (QuantMechanica V5 strategy_farm).
- Operating manual: C:/QM/repo/CLAUDE.md (16 Hard Rules)
- Full playbook: C:/QM/repo/docs/ops/GOAL_PROMPT_EA_TO_P8.md
- Pipeline-State-DB: D:/QM/strategy_farm/state/farm_state.sqlite

## Mission (Acceptance)
>=1 EA muss durch P8 cascaden: P2 -> P3 -> P3.5 -> P4 (WF 2023-2025 OOS)
-> P5/P5b/P5c -> P6 -> P7 -> P8. Acceptance fuer die Goal-EA:
- WF 2023-2025 OOS Sharpe >= 0.6
- Max DD <= 20%
- Trade count >= 30
- Survives P5/P6/P7/P8 sub-gates ohne DEAD verdict

## Aktueller Stand (Stand 2026-05-18 07:00 UTC)
- **Lead candidate**: QM5_1056 (top_PASS=P4, blockiert auf P5)
- **P5 FAIL reason**: "Calibration missing symbol block for EURUSD.DWX"
  (siehe: D:/QM/reports/pipeline/QM5_1056/P5/P5_QM5_1056_result.json)
- **Pipeline-queue**: 0 pending / 0 active work_items
- **Cards_ready**: 6 sources warten auf Strategy-Extraction + EA-Build
- **Pump (5min cron)**: laeuft, dispatcht MT5 wenn was zu tun

## Per-Session Work Loop
Nimm in einer Codex-Session ALLES was passt; exit clean wenn fertig
oder wenn Token-Quota erschoepft (codex login muss OWNER neu machen).

### Schritt 1 — Progress check
```
python -c "
import sqlite3
c = sqlite3.connect(r'D:/QM/strategy_farm/state/farm_state.sqlite')
for r in c.execute(\"SELECT phase, verdict, COUNT(*) FROM work_items GROUP BY phase, verdict ORDER BY phase\"):
    print(r)
"
```
Wenn 1 EA P8 PASS hat -> Stop sequence (siehe playbook).

### Schritt 2 — Priorisierte Aufgaben (pick highest-leverage first)

**PRIORITAET 1 (Goal-direkt): Fix QM5_1056 P5 calibration**
1. Lies P5-Script: framework/scripts/p5_*.py (grep "calibration", "EURUSD")
2. Schau auf Disk wo Calibration leben soll:
   - D:/QM/strategy_farm/calibration/  (existiert nicht)
   - state/p5_calibration*.json  (existiert nicht)
   - framework/registry/tester_defaults.json  (existiert)
3. Loesungspfade (pick one — keep small + focused):
   (a) Default-Calibration-Stub fuer EURUSD.DWX aus tester_defaults.json bauen
   (b) P5-Script patchen: missing-calibration -> WARN + Defaults statt FAIL
   (c) Auto-stub-Pfad in farmctl.py reparieren sodass er feuert
4. Re-enqueue P5 fuer 1056:
   python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_1056 --phase P5
5. Commit:
   git add framework/scripts/ tools/strategy_farm/ D:/QM/strategy_farm/calibration/
   git commit -m "fix(P5): EURUSD.DWX calibration unstuck fuer QM5_1056 P5"
   git push origin agents/board-advisor-session-2026-05-17

**PRIORITAET 2 (sobald P1 done oder du auf MT5 wartest):**
Strategy-Extraction aus den 6 cards_ready Sources. Hol naechste:
```
python -c "
import sqlite3
c = sqlite3.connect(r'D:/QM/strategy_farm/state/farm_state.sqlite')
for r in c.execute(\"SELECT id, source_type, uri, title FROM sources WHERE status='cards_ready' LIMIT 6\"):
    print(r)
"
```
Fuer jede Source:
1. Lies cards_ready proposal: D:/QM/strategy_farm/cards_proposed/<source_id>_*.md
2. Wenn strategy hat klare entry+exit+timeframe+symbol -> bau Strategy-Card
   nach D:/QM/strategy_farm/cards_approved/QM5_<next_id>_<slug>.md
3. Falls Symbol/TF SP500.DWX intraday: SP500.DWX Custom Symbol existiert
   T1-T10 (per OWNER's 2026-05-16T19:15Z Import), aber NICHT live-tradable.
   Backtest geht; OWNER-Approval fuer Live noch pending.
4. Build EA per:
   - prompts/SCHEMAS.md (build_result.json — KEIN phantom `status` field)
   - framework/V5_FRAMEWORK_DESIGN.md (RISK_FIXED+RISK_PERCENT beide,
     magic = ea_id*10000+slot, no ML, naming QM5_<id>_<slug>)
5. Schreib framework/EAs/QM5_<id>_<slug>/ + .mq5 + sets/ + build_result.json
6. Commit + push.

**PRIORITAET 3 (Bug Cleanup nur wenn P1+P2 nichts ergeben):**
Identifiziere stuck patterns via `python tools/strategy_farm/farmctl.py health`
und fix WARN/FAIL invariants per kleinem focused commit.

## Hard Guardrails
- KEINE erfundenen Commission/Swap/DST-Werte — quelle dokumentieren
  (tester_defaults.json, MT5 broker ticker, oder explizit "STUB" markieren)
- KEIN ML in Strategy-Code oder Calibration-Logik (Hard Rule 14)
- KEIN `terminal64.exe` manuell starten (transient via run_smoke.ps1)
- KEIN Touch auf C:/QM/mt5/T_Live/ — OWNER+Board-Advisor only
- KEIN force-push, NIEMALS main oder agents/board-advisor pushen
  Session-branch ist: agents/board-advisor-session-2026-05-17
- KEIN `codex login` — bei 401 sofort exit + OWNER eskalieren
- KEIN Test-Mocking — Pipeline laeuft echt, Calibration muss echt sein
- Bei jedem commit: pathspec verwenden (git add <files>), NIEMALS `git add .`

## NICHT in scope
- T_Live deployment / Live trading (OWNER+BA decision)
- Backtests starten (Pump dispatcht via run_smoke.ps1)
- Phase-Promotion entscheiden (Phase-Scripts entscheiden via verdict)
- Codex selbst restarten oder Auth toggeln

## Stop Conditions
1. **Token-Quota erschoepft / 401**: clean exit, OWNER eskalieren
2. **1056 P5 PASS** + P5b/P5c/P6/P7/P8 cascaden -> Goal erreicht ->
   schreib D:/QM/strategy_farm/dashboards/heureka_brief.md, force Gmail
3. **Saubere Pause-Punkt** (alle Tasks committet, naechste Aufgabe wartet
   auf MT5/Pump) -> exit clean, OWNER promptet dich neu

## Erste Aktion
Lies Playbook (cat C:/QM/repo/docs/ops/GOAL_PROMPT_EA_TO_P8.md), dann
starte mit Prioritaet 1 (P5 Calibration fuer 1056). Wenn 1056 P5 nach
deinem Fix re-enqueued ist, geh auf Prioritaet 2 (cards_ready builds).
