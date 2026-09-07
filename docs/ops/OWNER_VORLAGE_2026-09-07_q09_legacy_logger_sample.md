# OWNER-Vorlage 2026-09-07 — Q09/Q10_NEWS-Adjudikation für Builds vor dem 20.07. (Legacy-Logger-Sample)

Stand 16:55Z (lokal 18:55), CEO-Loop. Evidenz: `D:\QM\reports\work_items\f625d9aa-…\QM5_11167\Q10_NEWS\XAUUSD_DWX\aggregate.json`
(verdict `REVIEW_REQUIRED`, reason_codes `cell_execution_failed`, 8/8 Zellen `TransientCellError`), Zell-Log
`…\q09_contract_v3\cells\control_off__m0__c0__s17\runs\selection\run_smoke.log` (Zeile `Structured logger capture skipped: logger row is missing 'sv'` →
`run_smoke.ps1:3009 Required fresh structured logger sample was not authenticated`).

## Befund

Die erste B′-Adjudikation (QM5_11167/XAUUSD, T2, 07:18–16:00Z) hat **kein einziges authentifiziertes Zell-Ergebnis** geliefert. Ursache ist kein
Strategie- und kein Kalenderproblem: Der Q09-v3-Selektionslauf verlangt seit dem 04.08. (`-RequireFreshLoggerSample`) ein frisches, strukturiertes
Logger-Sample mit dem Pflichtfeld `sv` (Schema-Version). Das Feld kam am **20.07.** mit den P1-Evidenzintegritätskontrollen (6e92c80626) in
`QM_Logger.mqh`. EX5-Builds von davor schreiben Logger-Zeilen ohne `sv`; der Guard verwirft das Sample, `run_smoke` beendet mit Exit 1, die Zelle
gilt als transient gescheitert — bei jeder Wiederholung gleich.

**Umfang (gemessen, Q10_NEWS pending/aktiv):** 10 von 54 Zeilen tragen Pre-`sv`-Builds: 10148, 10476, 10771 (×2), 11179, 11196, 1230 (×2), 12474,
9573 — dazu 11167 (erledigt, REVIEW_REQUIRED). Von den 11 freigegebenen B′-Zeilen sind 3 pendende Pre-`sv`-Fälle (10771, 11196, 1230); 7 sind
Builds nach dem 20.07. und adjudizierbar. 11196 wurde von der Prioritätsspur genommen, damit kein weiterer 9-Stunden-Slot verbrennt.

## Optionen

| Option | Inhalt | Wirkung | Risiko |
|---|---|---|---|
| **A (Empfehlung): deklarierte Legacy-Authentifizierung nur im Q09-v3-Selektionslauf** | Für EX5 mit Build-Datum < 20.07. akzeptiert `run_smoke` ein Logger-Sample ohne `sv`, wenn alle übrigen Pflichtfelder (ts_utc, ts_broker, level, ea_id, slug, symbol, tf, magic, event, payload) vorhanden sind, ea_id/magic zum Lauf passen und das Delta gegen das Pre-Run-Archiv frisch ist; das Receipt trägt `logger_sample_authentication=legacy_no_sv` als deklariertes Residuum. Kein Threshold, kein Verdict, kein Gate-Kriterium ändert sich. | 10 Pre-`sv`-Kandidaten (und 11167 als Append-only-Rerun) werden adjudizierbar; Zählerpfad bleibt offen | Die Integritätskontrolle verliert für diese Builds die Schema-Versionsbindung; das Residuum steht im Receipt und in der Fußnote |
| B | Betroffene EAs neu bauen (E1/E2-v6-Regel: neue Identität ab Q02) | volle Integrität | Wochen: Q02→Q10-Kette für 10 EAs, Zählerbeitrag erst danach; Build-Lane und Recheck-Kapazität |
| C | Pre-`sv`-Zeilen aus dem B′-Pfad nehmen (parken) | nichts zu ändern | 10 Kandidaten fallen aus dem Zählerpfad; 3 der 11 freigegebenen B′-Zeilen ungenutzt |

**Empfehlung: A.** Die P1-Kontrolle bleibt für alle Builds nach dem 20.07. unverändert scharf; für die Altbestände wird das Residuum deklariert
statt der Adjudikation verweigert. Codex-Ticket: Guard-Erweiterung in `run_smoke.ps1` (nur unter `-RequireFreshLoggerSample` und nur wenn das
EX5-Build-Datum bzw. der Build-Record vor 6e92c80626 liegt), Tests mit Pre-/Post-`sv`-Fixtures, Receipt-Feld, Fußnote; danach 11167 als
Append-only-Rerun (`--append-only-rerun-of f625d9aa`) und 11196 zurück auf die Prioritätsspur.

## Was ein JA auslöst — genau ein Claude-Auftrag

Codex-Ticket (Guard + Tests + Receipt-Feld), Integration, Worker-Reload nicht nötig (run_smoke ist ein Skript je Lauf), dann Reruns 11167 und die
Pre-`sv`-Zeilen in Freigabe-Reihenfolge. Kein Repin, kein Publish, kein T_Live, keine Schwelle.

## Was ein NEIN auslöst

Option C sofort (Pre-`sv`-Zeilen bleiben ohne Prioritätsspur und werden dokumentiert geparkt); Option B nur nach separatem Build-Auftrag.

## Rollback

Guard-Erweiterung ist ein Skript-Flag/Build-Datum-Zweig; Entfernen stellt das heutige Verhalten her. Bereits adjudizierte Legacy-Zeilen tragen
das Residuum im Receipt und bleiben append-only nachadjudizierbar.
