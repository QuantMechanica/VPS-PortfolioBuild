# CODEX BRIEF — KS-Baseline-Gap (Pulse-ALARM 10/24): Plan-Review R1 (Topic B)

**Ticket-Klasse:** ops_issue · **Autor des Plans:** Claude · **Reviewer:** Codex (du)
**Protokoll (Ledger Topic B):** Adversarialer Review, explizite **Zustimmungs-%**.
`>= 90 %` -> Claude führt Phase 1 (file-side) aus und postet Evidenz; die
Ausführung wird danach in einem Folgeticket von dir verifiziert. `< 90 %` ->
Findings, Runde 2. **Dein Review ist strikt read-only.**

## Recon-Befund (Claude-Workflow 2026-07-31, evidenzgebunden)

Mechanismus: KS-Baseline = per-(EA,Symbol) Q10-Trade-Net-Verteilung für den
Kolmogorov-Smirnov-Kill-Pfad. Leser: `framework/include/QM/QM_KillSwitchKS.mqh`,
**genau EINMAL bei OnInit** (terminal-local `C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\baselines\`
ZUERST, dann Common `...\Terminal\Common\Files\QM\baselines\`); nie zur Laufzeit
re-gelesen; im Tester disarmed (MQL_TESTER-Guard). Datei auf Platte armiert einen
laufenden EA NICHT — erst ein frisches OnInit.

Gap-Klassen (Pulse 10 dormant / 4 missing / 20 divergent):
1. **Mirror-Divergenz (20 Sleeves):** terminal-local (WP-11-Regen, 07-25,
   autoritativ, wird zuerst gelesen) != Common (ältere Generation). Rein
   file-side schließbar, kein Restart nötig.
2. **Dormant (~7-9 echt):** korrekte terminal-local Dateien liegen, aber der
   letzte Re-Init (2026-07-29T07:28Z) loggte KS_BASELINE_ABSENT — die laufenden
   EAs haben seit Auflösbarkeit der Dateien nie re-initiiert. KEINE Dateioperation
   hilft; braucht T_Live-Re-Init. **10706|GBPUSD ist ein Pulse-Falsch-Positiv**
   (voller Log zeigt KS_BASELINE_LOADED 07-29T07:28:53Z; Pulse liest nur 4MB-Tail).
3. **Missing (4):** 1567|EURUSD + 13117|EURGBP haben STAGED Baselines
   (`D:\QM\reports\state\q10_baselines_staging\`, 07-25) -> file-side nach Common
   deploybar. 10513|XAUUSD: staged, aber dokumentierter Manifest-Provenienz-Defekt
   -> NICHT deployen vor sauberem Q10-Re-Confirm. 10440|NDX: keinerlei Baseline/
   Q10-Evidenz -> nur über Pipeline (Q10 PASS) schließbar.

Evidenz: `tools/strategy_farm/live_book_pulse.py`, `D:\QM\reports\state\live_book_pulse.json`,
`framework/scripts/gen_q10_baseline.py` (--deploy-live-Guard), EA-Logs
`C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\QM5_*.log`,
`docs/ops/2026-07-25_gate_repair_programme_PLAN.md` (WP-11).

## Plan

**Phase 1 — file-side (Claude, nach >=90 %; jederzeit sicher, da inert bis OnInit):**
1. Voll-Log-Grep KS_BASELINE_LOADED/ABSENT seit letztem OnInit je Sleeve ->
   autoritative Arm-Status-Tabelle (ersetzt die weiche Pulse-Zählung).
2. Backup: kompletter Common-Baselines-Ordner nach
   `D:\QM\reports\state\ks_common_backup_20260731\` (Rollback-Pfad).
3. Divergenz-Alignment: terminal-local -> Common **byte-identisch kopieren**
   (loader-truth; KEIN Regen — Regen kann erneut divergieren). SHA256-Tabelle
   vorher/nachher für alle 20.
4. Missing-Deploy: staging -> Common für **nur** 1567|EURUSD + 13117|EURGBP (SHA).
5. Pulse read-only neu laufen lassen: Divergenz muss 0 sein; dormant bleibt
   (erwartet, bis Phase 2).
6. KEINE Schreibzugriffe in den T_Live-Baum; kein Restart; kein 10513/10440.

**Phase 2 — Arming (Sonntag, Markt zu / Broker-Reopen ~22:00-23:00Z, OWNER+Claude):**
T_Live-MT5-Neustart gemäß stehender Prozedur (re-init't alle 24 Sleeves, lädt
Baselines bei OnInit; kombiniert mit 12778-Chart-Restore + Swap-Capture in der
einen Wartungssession). Danach: Voll-Log-Verify KS_BASELINE_LOADED für alle
abgedeckten Sleeves + Pulse-Run (Soll: OK bis auf 10440). Vorbedingung laut
07-29-Beweis: Restart NUR nachdem Phase-1-Dateien SHA-verifiziert auflösbar sind.

**Follow-ups (nicht dieses Ticket):** 10513 Q10-Re-Confirm; 10440 Q10-Pfad;
Pulse-Hygiene (4MB-Tail-Overcount -> Voll-Log- oder Marker-basierte Zählung).

## Review-Schwerpunkte

1. Richtung des Alignments: ist terminal-local (WP-11-Regen) wirklich die
   korrekte Wahrheit? Stichprobe: EINE Baseline per Namens-basiertem NET-Parse
   (Profit+Swap+Commission) gegen ihren Q10-Report prüfen (read-only).
2. Liest irgendein Codepfad Common zur LAUFZEIT (Behauptung: nein — widerlege
   oder bestätige mit file:line)?
3. Backup/Rollback vollständig? Restart-Risiken korrekt erfasst (3 offene
   Positionen, Magics 114210000/114210003/117080000)?
4. Ist der Copy-Weg konform zum --deploy-live-OWNER-Gate von
   `gen_q10_baseline.py` (prozedural: OWNER-Direktive vom 2026-07-31 deckt
   Phase 1; das Arming bleibt OWNER+Claude Sonntag)?

## Deliverable

`docs/ops/evidence/2026-07-31_ks_baseline_gap_plan_review.md`: Zustimmungs-%,
Findings, Stichproben-Evidenz. Danach `update-task <id> --state REVIEW
--artifact-path <deliverable> --verdict "<kurz>"`.
