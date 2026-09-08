# Dropbox→Drive: zwei Fehlerdateien und Supervisor-Retry-Folgeauftrag

Snapshot UTC: 2026-09-07T22:48:05.476601+00:00. Lokal: 08.09.2026, 00:48 Uhr Wien. Status: **Kopie läuft weiter; zwei Fehlerdateien sind nicht verifiziert; kein automatischer Folge-Retry im geprüften Transfer-/Supervisor-Pfad. Factory bleibt OFF.**

Dieser Auftrag hat ausschließlich vorhandene Status-/Journaldateien, Worker-Quellen und die eingebettete Supervisor-Steuerung gelesen. Einzige neue Datei ist diese Notiz. Keine Prozesse gestartet/gestoppt, keine Queue verändert, keine Wiederholung ausgelöst, keine Quelldateien entfernt.

## Snapshot und genau zwei Fehlerdateien

Die lokale SQLite-Datei wurde mit `mode=ro`, `PRAGMA query_only=ON` und einer gemeinsamen Lesetransaktion geöffnet. Zustände: verified **26.562**, pending **12.040**, downloading **3**, staged **3**, error **2**; insgesamt 38.610. „Zwei nicht verifizierte Fehlerdateien“ bedeutet nicht, dass nur noch zwei Dateien im Gesamtplan fehlen.

Der separat veröffentlichte [Drive-Status](<G:/My Drive/Forex-Transfer Steuerung/Forex-Transfer Status.json>) war etwas älter: 2026-09-07T22:47:39.284259+00:00, `state=running`, verified 26.542/38.610, errors=2, `final_audit=pending`, source_deletions=0. Die Differenz von 20 Verifikationen ist mit den unterschiedlichen Snapshot-Zeiten vereinbar; kein identischer Messzeitpunkt wird behauptet.

| Datei / Ziel relativ zum Kopierroot | Größe | Fehler UTC / Typ | Aktueller DB-Befund |
|---|---:|---|---|
| `02 Programmierung und Algotrading/Kurse/The Ultimate Forex Algorithmic Trading Course  Build 5 Bots/13 - Bot 04 -Grid Bot- Download the Final Bot Here/Grid bot/venv/Lib/site-packages/pandas/tests/io/parser/common/__pycache__/test_decimal.cpython-310.pyc` | 1.695 Bytes | 07.09., 21:49:54 — Dropbox HTTP **504**, Öffnen des Quellobjekts fehlgeschlagen | `status=error`, `verified=NULL` |
| `01 Kurse/Forex und Trading/Daye's Quarterly Theory Mentorship/Daye's Quarterly Theory Mentorship/13. Market Analysis (2-11-24).mp4` | 106.293.961 Bytes | 07.09., 21:50:20 — Dropbox HTTP **500** beim Download | `status=error`, `verified=NULL` |

Sichere lokale Belege:

- [Aktuelles Transferjournal](C:/Users/Administrator/AppData/Local/ForexTransfer/VPS-20260907-1ee3275589/transfer-state.sqlite): Tabelle `transfers`, exakt zwei Zeilen mit `status='error'`; beide Fehlermeldungen `dropbox_download failed; see events.jsonl`.
- [HTTP-504-Ereignis](C:/Users/Administrator/AppData/Local/ForexTransfer/VPS-20260907-1ee3275589/events.jsonl:53857), zugehöriges `file_error` Zeile 53859.
- [HTTP-500-Ereignis](C:/Users/Administrator/AppData/Local/ForexTransfer/VPS-20260907-1ee3275589/events.jsonl:53960), zugehöriges `file_error` Zeile 53962.

Für genau diese beiden Fehler ergab das Journal keine spätere Verifikation. Es handelt sich um Download-Serverfehler, nicht um einen hier belegten Hash-/Drive-Verifikations-, Quota- oder Authentifizierungsfehler. Wiederholung ist grundsätzlich möglich; deren Erfolg ist noch ungeprüft. Ein irreparabler Quellverlust ist nicht nachgewiesen. Der ältere Fortschritt-ZIP vom 22:23 Uhr wurde nicht als aktueller Journalnachweis verwendet.

## Retry-Abdeckung: Transferpass und Supervisor getrennt geprüft

**Transferpass:** Nach einer Ausnahme setzt [transfer.py](C:/Users/Administrator/AppData/Local/ForexTransfer/VPS-20260907-1ee3275589/transfer.py:138) die Datei auf `error`. Der [Scheduler](C:/Users/Administrator/AppData/Local/ForexTransfer/VPS-20260907-1ee3275589/transfer.py:239) nimmt anschließend die nächste Queue-Datei; [WorkQueues](C:/Users/Administrator/AppData/Local/ForexTransfer/VPS-20260907-1ee3275589/transfer_queue.py:14) besitzt keinen Requeue-Schritt. Das belegt allein noch nichts über einen späteren Supervisor-Retry. Ein neuer normaler Lauf berücksichtigt nicht verifizierte Dateien; die gezielte Fehlerauswahl `--retry-errors` ist im [vorhandenen Programm](C:/Users/Administrator/AppData/Local/ForexTransfer/VPS-20260907-1ee3275589/transfer.py:194) implementiert.

**Separater Supervisor:** Die sichere Prozessmetadatenprüfung identifizierte den aktiven Worker PID 20992 und dessen Parent PID 20548 als `Forex-Transfer-VPS.exe`. Vollständige Commandlines wurden nicht ausgegeben. Die vorhandene [Anwendung](<G:/My Drive/Forex-Transfer-VPS.exe>) wurde nicht ausgeführt, sondern ihr eingebetteter Eintrag `launcher` ausschließlich statisch im Speicher gelesen. Seine Funktion `launcher.py::supervisor` zeigt folgenden Kontrollfluss:

| Eingebettete Quellzeile | Beobachtete Steuerung |
|---|---|
| 142–143 | Argumentliste mit Workers/Drive-TPS, ohne `--retry-errors`; genau ein Aufruf `transfer.run()` auf diesem Pfad. |
| 144–147 | Nach Rückkehr: `count(*) WHERE status!='verified'`. Bei Restbestand wird `stopped` veröffentlicht und der Bediener auf **Fortsetzen im Starter** verwiesen. |
| 149–152 | Nur ohne Restbestand startet der abschließende Quellen-/Zielabgleich; danach `complete` oder `audit_attention`. |
| 157, 160–163 | Abschluss-/Publisher-Signal, anschließend Warteschleife für `close-supervisor.json`; kein Rücksprung zum Transferaufruf. |

Damit ist für **diese geprüfte Supervisor-Version** kein automatischer `--retry-errors`-Lauf nach dem aktuellen Pass vorgesehen. Falls die zwei Fehler bis dahin bestehen bleiben, führt der gezeigte Pfad zum gespeicherten Stoppzustand und wartet auf kontrolliertes Fortsetzen. Das ist eine statische Folgerung, noch kein beobachteter Abschluss dieses weiterhin laufenden Passes. Unbekannte externe Orchestrierung oder spätere Bedieneraktionen wurden nicht ausgeschlossen; daraus wird kein universelles „der gesamte Workflow versucht nie erneut“ abgeleitet.

Provenienz der statischen Supervisor-Prüfung:

- EXE: 55.113.964 Bytes; beobachtete letzte Änderung 07.09.2026, 16:42:19.967 UTC.
- Eingebetteter Python-Versionsmarker: 3.12; SHA256 des dekomprimierten `launcher`-Eintrags: `22ea32ef19c1ea9b806e5ed7614e01c8e56cfe1dd1babfa0074c0b526bb9dd78`.
- SHA256 des originalen rohen Supervisor-Bytecodes: `bcd826fc5e6abf76311ea97a1577c85f260c18c6ac87962b65ad61e0566f0e6e`.
- Auswertung der originalen Bytefolge, nicht Ausführung des Codeobjekts; Kontrollflusszuordnung anhand der [CPython-3.12-Opcode-Definition](https://raw.githubusercontent.com/python/cpython/v3.12.0/Include/opcode.h). Die Supervisor-Zeilennummern beziehen sich auf eingebettete Metadaten; eine physische `launcher.py` wurde nicht vorgetäuscht. Keine EXE, Konfiguration oder Archivdatei wurde verändert oder auf Disk extrahiert.

## Separates Retry-TODO, jetzt nicht ausgeführt

1. Laufenden Pass ungestört beenden lassen und Restbestand neu read-only prüfen.
2. Wenn diese Dateien weiterhin `error` sind: in einem eigenen Folgeauftrag den vorhandenen kontrollierten Fortsetzungsweg nutzen; keinen zweiten Parallelworker starten. Alternativ ist ein gezielter Fehlerlauf technisch vorhanden, aber hier weder gestartet noch in den Supervisor eingebaut.
3. Beide Dateien müssen anschließend Source-Hash/Größe sowie Drive-Readback/MD5 erfolgreich durchlaufen und im Journal `verified` tragen. Die kleine `.pyc` bleibt Bestandteil des unveränderten Kopierplans; weder überspringen noch löschen, nur weil sie vermutlich wenig Forschungswert hat.
4. Erst vollständigen Plan und finalen Auditnachweis abnehmen. Die Factory bleibt bis zum belegten Kopierabschluss OFF; weder eine hohe Prozentzahl noch zwei vermeintlich unwichtige Ausnahmen ersetzen diesen Nachweis.

Datenschutz: Keine privaten Konfigurationsdateien gelesen, keine Tokens/Credentials ausgegeben, keine Account-/Handelsdaten extern gesendet. Der einzige externe Technikabruf betraf die allgemeine öffentliche CPython-Opcode-Definition.

