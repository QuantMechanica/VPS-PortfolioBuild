# Phase-4 Crash-Fix — headless Codex: Full-History-5-Modul-Tester-Stabilität

**Rolle:** headless Codex. **PM:** Claude. **Worktree:** `agents/codex-master-ea-p4crashfix`
(nie main, nie T_Live, nie T1/T2). **Non-live, reversibel.**
Kontext: `docs/ops/MASTER_EA_SYMBOL_CONSOLIDATION_PLAN_2026-07-13.md` (Phase 4) +
`docs/ops/evidence/master_ea_phase4_integration_2026-07-13.md` (die bereits erbrachten Beweise).

## Ausgangslage (Verhalten ist BEWIESEN — das hier ist ein Stabilitäts-, kein Korrektheits-Task)
`QM5_MXAU_master-xauusd` (ea_id 20001) = 5 XAU-Module. Bereits verifiziert:
- 5/5 per-Modul full-history centgenau (allein im Master).
- 5/5 keine Cross-Modul-Interference (confound-freier Fenster-Test).

**Der Defekt:** der Full-History-Lauf mit ALLEN 5 Modulen (XAUUSD.DWX, H4, Model 4, 2017–2025)
**crasht den Strategy-Tester still bei ~95 %** (~40 min Wall-Clock, KEIN geloggter Error, KEIN
Gate-Timeout-Kill — das terminal64 stirbt selbst), **vor** dem OnDeinit-q08-Write → kein Stream.
Einzelmodul-Läufe laufen full-history sauber durch; es ist die **kombinierte** Last.
Prime-Verdacht: **EtTurtles Turtle-Breakout-Pending-Order-Churn** (BUY_STOP+SELL_STOP, pro Bar
neu gesetzt, meiste laufen ab → tausende Order-Ops) × 5 Module über 9 Jahre → Tester-History/
Memory-Wachstum bis Absturz. Evidenz: Tester-Log voll „order expired"/„buy stop"/„sell stop"
aus magic 104030002.

## Aufgabe (in dieser Reihenfolge)

### 1. Charakterisieren (Backtests, freies T6–T10)
Isoliere die Ursache — ist es EtTurtle-spezifisch oder kumulative Last?
- 4-Modul-Set OHNE EtTurtle (strategy1 off, 2/3/4/5 on, FIXED 1000) full-history H4 → läuft es durch?
- Nur EtTurtle + 1 anderes (2 Module) full-history → läuft es durch?
- Optional: alle 5 auf **D1**-Chart statt H4 (weniger Primär-Bars) → durch?
Ziel: eine klare Aussage, WAS den Crash triggert (EtTurtle-Order-Churn vs. genereller Tester-
Memory-Deckel bei N Modulen).

### 2a. Falls EtTurtle-Order-Churn die Ursache: fixen (VERHALTENSNEUTRAL)
Optimiere das Pending-Order-Handling in `QM_Mod_EtTurtle20x.mqh` (und/oder der Trade-Schicht):
identische Stop-Orders NICHT jede Bar canceln+neu-anlegen, sondern nur **amendieren, wenn sich
das Level ändert** (spart Order-Ops → entlastet Tester-History; hilft auch dem Standalone).
**★HARTE AUFLAGE — NULL Verhaltensänderung:** die Fill-Preise/Trades müssen bit-identisch
bleiben. Nach dem Fix MUSS der EtTurtle-per-Modul-Gate weiter **209 Trades / $14.411,17
centgenau** liefern (Master mit nur strategy1, FIXED 1000, full-history 2017–2025, D1). Jede
Abweichung = der Fix ändert Verhalten = Blocker.

### 2b. Falls kumulativer Tester-Memory-Deckel (nicht EtTurtle-spezifisch):
Kein Code-Zwang. Dokumentiere es als Tester-Limitation. Prüfe Optionen (z.B. Tester-Speicher-
Settings, Chart-TF, chunked-Validierung). Das Verhalten ist ohnehin schon bewiesen (per-Modul +
Interference); dann ist der Full-History-Single-Pass nur ein Record-Nice-to-have.

## Acceptance-Gate
Entweder:
- **(A)** Nach dem Fix läuft der Full-History-5-Modul-Lauf (INTEGRATION_ALL5.set, 2017–2025)
  **durch bis OnDeinit**, der q08-Stream dekomponiert je Magic in die 5 Referenzen **centgenau**
  (104030002 209/$14.411,17 · 105130003 76/$9.649,32 · 125670003 73/$4.676,76 · 129890003
  51/$13.878,26 · 15560004 53/$6.369,87) — UND der EtTurtle-per-Modul-Gate bleibt 209/$14.411,17.
ODER:
- **(B)** Eine belegte Charakterisierung, dass es ein Tester-Memory-Limit ist (mit den
  Backtest-Belegen), plus Empfehlung — ohne verhaltensändernden Hack.

## Prozess-Pflicht
- Backtests SYNCHRON fahren, nicht backgrounden. Vor jedem Smoke die Worktree-`.ex5` ins
  Ziel-Terminal deployen (run_smoke deployt aus C:\QM\repo). **Committen vor exit** — auch bei
  Ergebnis (B). Uncommitteter Worktree = Fail.
- KEINE Verhaltensänderung an den anderen 4 Modulen / am Framework-Kern (Phase 1/2.5). Wenn du
  EtTurtles Order-Handling änderst, re-verifiziere den EtTurtle-Gate centgenau.

## Deliverable
PR auf `agents/codex-master-ea-p4crashfix`: Charakterisierungs-Belege + (bei 2a) der
verhaltensneutrale Fix mit grünem EtTurtle-Regnungs-Recheck, Design-Notiz. Claude fährt den
autoritativen Full-History-Integrations-Gate + merged.
