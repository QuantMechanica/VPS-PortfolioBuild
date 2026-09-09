# FTMO: vorhandene Kandidaten schneller zur wirtschaftlichen Entscheidung bringen

Status: **ACTIVE — Vorbereitung und Qualifikation, keine Kauf-/Handelsfreigabe**.
Entscheidung: `AGENT-DEC-FTMO-ACCELERATION-20260909`, dokumentiert in
`decisions/2026-09-09_ftmo_acceleration_delegated.md` mit dem aktuellen
OWNER-Auftrag und der delegierten Entscheidungsgewalt.

## Was jetzt anders priorisiert wird

Der erste Liefergegenstand ist ein kleines FTMO-Pilotpaket aus maximal fünf
vorhandenen Kandidaten: tatsächliche Kosten, FTMO-Zulassung, gemeinsames Risiko,
nachgewiesene Ausführung und ein vorab festgelegter Test. Seine Vorbereitung
wartet nicht auf 25 Kandidaten. Die 25er-Regel des regulären Portfolio-Builders
bleibt bestehen; dieses Paket ist kein freigegebenes Portfolio.

Die Zielgröße ist der erwartete Netto-Cashflow bis zur ersten Auszahlung.
Challenge-Passrate, reguläre Kandidatenzahl und Zahl der Backtests sind
Zwischenmessgrößen. Für die freie Vorbereitung gilt externes Budget 0.
Der mehrjährige R5-Nachweis behält seine statistische Bedeutung; ein kurzer
Lernversuch ersetzt ihn nicht. Eine neue wirtschaftliche Entscheidung muss
Unsicherheit explizit benennen und kann keinen R5-PASS erzeugen.

## Frisch gemessen und bereits umgesetzt

Snapshot `evidence/2026-09-09_ftmo_acceleration/intake.json`, 09.09. 21:21 UTC:

- **16** Paare im kanonischen zusammenhängenden Q14-Pool.
- **0** davon bestehen derzeit das bestehende FTMO-News-Zulassungsgate.
- **12** haben Evidenz ohne den erforderlichen FTMO-Scope, **3** fehlen im
  Zulassungsleser, **1** ist nicht `CONFIG_LOCKED`.
- Der Leser fragte ausschließlich `Q09_NEWS` ab, während die aktuelle Pipeline
  `Q10_NEWS` schreibt. Die Reparatur liest den aktiven Namen aus dem Gate-Manifest
  sowie den historischen Alias und verwendet den neuesten abgeschlossenen
  Nachweis. Authentifizierung, Matrixabdeckung und Wirtschaftsschwellen bleiben
  identisch. Ein neuer ablehnender Nachweis kann nicht durch ein altes PASS
  übergangen werden.
- **27 Tests PASS**, einschließlich Phasenmigration, manipuliertem Artefakt und
  Vorrang eines neueren ablehnenden Ergebnisses. Kein Pipeline-Verdikt verändert.

Die null Zulassungen sind kein Nachweis einer Erfolgswahrscheinlichkeit von null.
Der reparierte Leser zeigt, welche zielbezogenen Nachweise fehlen. Der
reguläre Q14-Zähler allein misst diese FTMO-Lücke nicht.

Die veröffentlichte Kostenprojektion vom 05.09. ist explorativ, ohne Spreaddelta
und nicht auf heutige Binary-Identitäten übertragbar. Sie macht die Kostentriage
dringlich: 1537/XAGUSD wechselt von +3.647,61 auf -1.876,79 USD vor Spreaddelta.
Diese Summen stammen aus historischen Streams und sind keine Ertragsprognose.
M08 enthält keine zeitlich passenden FTMO/DXZ-Minuten. Native Spezifikationen
vom 06.09. ergänzen jedoch echte Swap-/Triple-Day-Werte; sie sind dem generischen
Mittwochsansatz vorzuziehen. Aktuelles Demo-Profil: Standard, nicht Swing.

## Vier begrenzte Aufträge

| Spur | Prio | Primäre Lane | Ergebnis |
|---|---:|---|---|
| A Zulassung | 99 | Codex | aktuelle Vertrags-/Identitätsprüfung, gezielter FTMO-Qualifikationsplan, ausführbarer Dry-Run und Tests |
| B Kosten/Shortlist | 98 | Codex | alle 16 vergleichen, null bis fünf begründet auswählen, native Kosten binden, nur benötigte Datenlücken schließen |
| C Ausführung | 97 | Codex | isolierter 11421-Kanari mit Governor-/Risikobudgetanbindung, vollständiger Order-Lifecycle, native Negativtests und Requalifikationsplan |
| D Ökonomie/Testvertrag | 96 | Claude | Kosten-/Erstattungs-/Reward-Modell, Break-even-Sensitivität, prospektiver Testvertrag und konkrete Disposition |

Auftrags-IDs und persistierte Zustände stehen in
`evidence/2026-09-09_ftmo_acceleration/commission_receipt.json` und der
kanonischen `agent_tasks`-Tabelle. **Beauftragt ist nicht fertiggestellt.**
Der vorhandene Router übernimmt die Aufträge nach Verfügbarkeit; laufende
Arbeit wird nicht unterbrochen und Quoten werden nicht umgangen.

Erste überprüfbare Shortlist: **12.09.2026, 22:00 UTC** als Arbeitsziel.
A/B/C können unabhängig vorbereiten; D kann Modell und Vertragsstruktur sofort
erstellen. Eine verbindliche neue Testversiegelung wartet auf die akzeptierten
Kosten-, Ausführungs- und Kandidatenversionen. Der laufende M13-Capture bleibt
explorativ. Ein Termin für Profitabilität lässt sich daraus nicht ableiten.

## Reproduktion und Kontrolle

```powershell
python -m pytest -q tools/strategy_farm/tests/test_ftmo_q09_admission.py tools/strategy_farm/tests/test_ftmo_qualification.py
python docs/ops/evidence/2026-09-09_ftmo_acceleration/collect_snapshot.py <neuer-snapshot.json>
```

Der Snapshot öffnet SQLite ausschließlich read-only und schreibt eine neue
Datei; bestehende Snapshots werden nicht überschrieben. Der ursprüngliche
Leserbefund wird im selben Read-Snapshot mit dem reparierten Leser verglichen.
Gebundene Quellhashes sind im JSON enthalten. Kein Holdout wird dabei geöffnet.

Vault-Prüfung: 10 bestehende Meldungen zu alten Gate-Bezeichnungen; der virtuelle
Vergleich ohne genau diese neuen Programm-/ToDo-Blöcke ergibt dieselben 10
Meldungen, **0 neu eingeführt**. Details in
`evidence/2026-09-09_ftmo_acceleration/vault_lint_delta.json`.

FTMO beschreibt den Free Trial als Vorbereitung; er garantiert keinen späteren
Challenge-Erfolg. Beim 2-Step-FTMO-Account kann der erste Reward ab dem 14. Tag
nach dem ersten Trade beantragt werden. Diese Frist beginnt auf dem jeweiligen
FTMO-Account, nicht beim heutigen Demo-Test; sie ist keine Zusage einer Auszahlung
in zwei Wochen. Quellen, am 09.09.2026 geprüft:
[Free Trial](https://ftmo.com/en/faq/how-about-a-free-trial/) und
[Reward-Anforderung](https://ftmo.com/en/faq/how-do-i-withdraw-my-profits/).
