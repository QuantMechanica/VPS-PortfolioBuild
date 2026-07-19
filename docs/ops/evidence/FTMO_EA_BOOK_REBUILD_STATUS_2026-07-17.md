# FTMO EA Book Rebuild Status — 2026-07-17

## Ergebnis

Die Bucharchitektur ist vollständig definiert, der Challenge-Start bleibt jedoch `NO_GO`. Freigegeben sind Forschung, Card-Adjudication und Build-Tests. Nicht freigegeben sind Challenge-Kauf, Live-Deployment, T6-Änderungen und AutoTrading.

Der Unterschied ist wichtig: Ein vollständiges Buch beschreibt Rollen, Regeln, Risiko, Phasenwechsel und Beweisgates. Ein startfähiges Buch benötigt zusätzlich mehrere unabhängige EAs mit durchgehender aktueller Pipeline-Evidenz. Diese Evidenz ist noch nicht vollständig.

Kanonische V3-Artefakte dieser Entscheidung sind `docs/research/FTMO_CHALLENGE_EA_TARGET_BOOK_2026-07-17.md` und `artifacts/ftmo_rebuild_2026-07-17/ea_design_target_book.json`. Ältere `candidate_book_manifest.json`-/`candidate_book_readiness.json`-Dateien im gleichen Rebuild-Ordner bleiben historische Scaffold-Snapshots und sind keine V3-Freigabeakte.

## Aktueller Rollenstand

| Rolle | Kandidat | Technischer Stand | Buchzulassung |
|---|---|---|---|
| Account-Governor | QM5_13206 V2 | `APPROVE_FOR_BUILD_TEST`; 18 Python-Tests PASS, Client-Compile 0/0, Governor Build-Check 0/0 | `BLOCKED_LIVE` |
| FX-Dichtemotor | QM5_4006 SessionFlow | APPROVED, gebaut, Compile/Build 0/0; Q02 auf T1/T2/T3/T4 jeweils vor Marktdaten mit History-Sync-Fehler abgebrochen | `UNDECIDABLE_INFRA`, nicht zugelassen |
| Kalender-FX | QM5_12969 Gotobi | reparierter Vertrag; frischer T1-Q02 mit zwei deterministischen Model-4-Läufen PASS | Q03 läuft; noch nicht zugelassen |
| Equity-Microstructure | QM5_4007 MAC5 | Card APPROVED und Strict Build 0/0; gültiger deterministischer Q02 ergab 0/0 Trades, weil D1-Anker-Orders `Market closed` erhielten und der Einmalversuch bereits verbraucht war | `FAIL_ZERO_TRADES_BELOW_COHORT_NO_DISPATCH`, aus aktuellem Buch ausgeschlossen |
| Turn-of-the-Month | bestehender QM5_20004 | neuer TOM-Entwurf als exaktes Duplikat verworfen; kein zweiter TOM-EA | bestehende Lineage nicht aktuell qualifiziert |
| Slow Diversifier | unbesetzt | Read-only Audit: QM5_12382 Q04 ungültig; QM5_10377/QM5_10513 ohne identische Q02→Q04-Lineage; QM5_12897 Kosten-Hard-Fail | `ROLE_UNFILLED`; kein Kandidat erzwungen |

## Harte Evidenz

### QM5_12969 Gotobi

Frischer Vertrag-v2-Q02 auf T1, USDJPY.DWX M30, 2017–2022, Model 4:

| Kennzahl | Lauf 1 | Lauf 2 |
|---|---:|---:|
| Trades | 213 | 213 |
| Profit Factor | 1,57 | 1,57 |
| Netto | 6.062,13 | 6.062,13 |
| Equity Drawdown | 1,89 % | 1,89 % |

- Summary: `D:\QM\reports\pipeline\QM5_12969_usdjpy-gotobi-nakane-fix\Q02_contract_v2_T1\QM5_12969\20260717_104210\summary.json`
- Summary SHA-256: `bb8d3c7ac14a82e3e78cefec965fdc035d4ad76b59c2e2bda673ff022d99f291`
- EX5 SHA-256: `933d63c036a154725df1376e22ca74cb419860588f0313fc986fc3ead7673be4`
- Card SHA-256: `f8989e1e7e6592d601a2142a8b0daf8449d0e33d8f638d4521077bfa1c321e4c`
- Q03 ist vor Ausführung auf die alleinige Stop-Achse `[60, 90, 120, 150, 180, 240, 360]`, zwei Läufe je Zelle, mindestens 180 Trades, mindestens 50 % profitable Zellen und Plateau-Breite 3 gebunden.
- Preregistration: `artifacts/ftmo_12969_usdjpy_q03_grid_predeclaration_2026-07-17.json`, SHA-256 `7cf4b4c061430cdebe9c749aca27725cb1b2e7a3c6e8c9c590789fd53f88b481`.

Die früheren FTMO-Re-Costing-Ergebnisse bleiben nützliche Vor-Evidenz, dürfen aber erst nach Q03-Auswahl und neuer Q04–Q10-Lineage als Release-Evidenz verwendet werden.

### QM5_4006 SessionFlow

- Build-Check: `D:\QM\reports\framework\21\build_check_20260717_100152.json`, PASS, 0 Fehler, 0 Warnungen.
- Finaler Recovery-Versuch: `D:\QM\reports\pipeline\QM5_4006_fx-session-flow\Q02_recovery_T4\QM5_4006\20260717_102256\summary.json`.
- T1–T4 endeten jeweils mit `EURUSD.DWX: history synchronization error`, 0 Bars/Ticks und ungültigen Leerreports.
- Urteil: kein Strategieversagen, aber auch kein PASS. Ohne gültige Q02-Daten ist der EA kein Buchbaustein.

### QM5_4007 MAC5

- Strict Build-Check: `D:\QM\reports\framework\21\build_check_20260717_110304.json`, PASS, 0 Fehler, 0 Warnungen.
- EX5 SHA-256: `8c5ed569d5abe7fb8fffa2b8cdf93e0b59d1613bc0f6b13302e3704bd612cd6d`.
- Gültiger T2-Q02 Model 4: zwei deterministische Läufe, je 32.246 Report-Bytes, aber jeweils 0 Trades, PF 0,00 und Netto 0,00.
- Summary: `D:\QM\reports\pipeline\QM5_4007_index-mac5-rev\Q02_research_T2\QM5_4007\20260717_110744\summary.json`, SHA-256 `d9005a82b18cfbe4f881ec95b3935a7dbd0ff37d04e62e668ad909bd094480a3`.
- Das Journal belegt abgewiesene `SP500.DWX`-Orders am Broker-D1-Anker mit `[Market closed]`; der Build persistiert davor bereits den täglichen One-shot-Versuch.
- Da nur `SP500.DWX` durch die Card autorisiert ist, beträgt die Zero-Trade-Kohorte 1/5. Nach dem Recovery-Protokoll endet der Vorgang als `BELOW_THRESHOLD_NO_DISPATCH`: kein stiller Fix, kein v2-Dispatch, kein Q03.

Root-Cause-Akte: `framework/EAs/QM5_4007_index-mac5-rev/ZT_RootCause_QM5_4007_20260717.md`. Das Ergebnis bewertet nicht die ökonomische MAC(5)-These; es verwirft diese konkrete Binary für das aktuelle Buch.

### QM5_13206 Governor V2

Der Governor enthält unveränderliche 100k-Profile für Phase 1, Phase 2 und Funded. Der unabhängige Re-Audit lautet `APPROVE_FOR_BUILD_TEST`.

- Strict Build-Check: `D:\QM\reports\framework\21\build_check_20260717_105002.json`, PASS, 0/0.
- Python Policy/Wiring: 18 PASS.
- Profile: `FTMO_2S_P1_100K_V2`, `FTMO_2S_P2_100K_V2`, `FTMO_2S_FUNDED_100K_V2`.
- Dry-run-Default kann weder Clients entriegeln noch Trades liquidieren.

Live bleibt gesperrt, bis der Target-vor-Tag-4-Pfad, exakte Prague-Midnight-/Deal-Time-Zuordnung, signierte Manifest- und Magic-Bindung, History-reconciled Bootstrap, produktive Client-Verdrahtung, T1–T5-Faulttests, OWNER-Live-Manifest und T6-Read-only-Verifikation geschlossen sind.

## Warum das Buch noch kein Challenge-Go erhält

1. Kein einziger Alpha-EA besitzt bereits eine vollständige aktuelle Q02–Q08/Q10-Kette auf derselben Binary.
2. Der geplante Dichtemotor ist wegen Terminal-History-Infrastruktur nicht entscheidungsfähig.
3. Gotobi ist erst nach Plateau-Auswahl und neu erzeugter Downstream-Lineage belastbar.
4. MAC5 ist in Q02 terminal an null Trades gescheitert und darf nach dem Kohortenprotokoll in dieser Lineage nicht repariert oder weitergereicht werden.
5. Governor und Alpha-EAs sind noch nicht produktiv miteinander verdrahtet.
6. Gemeinsame OOS-/Monte-Carlo-Zeit-bis-Ziel- und VPS-Wirtschaftlichkeit kann erst mit mindestens zwei hart qualifizierten, unabhängigen Rollen gerechnet werden.

## Nächste ausführbare Kette

1. Gotobi-Q03 abschließen, Plateau-Median einfrieren und Q04–Q10 auf exakt dieser Binary/Set-Lineage neu erzeugen.
2. SessionFlow-History-Synchronisierung außerhalb der EA-Logik reparieren und denselben eingefrorenen Build erneut Q02 prüfen.
3. Für Equity-Microstructure und Slow Diversifier nur einen neu bzw. sauber lineage-gebunden qualifizierten Kandidaten zulassen; MAC5 v1 bleibt terminal ausgeschlossen.
4. Governor-Liveblocker schließen und jeden später zugelassenen EA an den V2-Client binden.
5. Nur mit mindestens zwei unabhängigen Pipeline-Champions die synchronisierte Phase-1-/Phase-2-/Funded-Simulation und die konkrete Challenge-/VPS-Kostenrechnung durchführen.

Bis diese Gates bestehen, bleibt das operative Urteil `RESEARCH_COMPLETE_ENOUGH_TO_CONTINUE`, aber `CHALLENGE_PURCHASE_ALLOWED=false` und `DEPLOYMENT_ALLOWED=false`.
