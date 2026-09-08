# EURUSD-EA: Design 1 und Design 2 — finale Übergabe

Stand: 08.09.2026. **Design 2 ist auf dem ursprünglichen EURUSD-D1-EA11421 im bestehenden FTMO-Demo-Terminal installiert.** Der finale Build `4ff02978` ist einschließlich der Absicherung für Größenänderungen und expliziter Anzeige-Wiederherstellung aktiv. `INIT_OK` wurde am 08.09.2026 um 01:24:27 Wiener Zeit bestätigt. Der Chart steht wieder auf Design 2 / Full. Dies ist eine Design-Überarbeitung, keine neue Trading- oder FTMO-Freigabe.

## Direkt vergleichen

Die beiden echten Terminalansichten stehen zur Auswahl: [Design 1 ansehen](C:/QM/repo/docs/ops/evidence/2026-09-07_strategy_console_v2/design_1_final_ftmo.png) · [Design 2 ansehen](C:/QM/repo/docs/ops/evidence/2026-09-07_strategy_console_v2/design_2_final_ftmo.png). Für weniger Platzbedarf: [Compact](C:/QM/repo/docs/ops/evidence/2026-09-07_strategy_console_v2/design_2_compact_ftmo.png) · [Minimal](C:/QM/repo/docs/ops/evidence/2026-09-07_strategy_console_v2/design_2_minimal_ftmo.png).

Auf dem Chart zeigt **01/02 das aktuelle Design**: Ein Klick auf **02** wechselt zu Design 1, ein Klick auf **01** zurück zu Design 2. Der Wechsel wurde am Original-EA nativ geprüft. Er schaltet die Darstellung um, ohne den EA neu zu initialisieren, Inputs zu ändern oder Handelsaufrufe auszulösen. Kurs und Countdown können zwischen den echten Screenshots trotzdem variieren, weil der EA seine reguläre Aktualisierung fortsetzt.

## Was sich geändert hat

Design 1 bleibt als kompakter Vergleich erhalten. Design 2 kombiniert ein neu gegliedertes Dashboard mit einer eigenen, reversiblen Chartdarstellung: Status und nächstes Ereignis stehen oben, geplantes Einstiegsrisiko und bestehendes Positionsrisiko sind getrennt, darunter folgen Stopbasis und Performance. Die Chartbeschriftung ergänzt Symbol, Strategie-Zeitrahmen und beobachteten Kurs.

Das echte **©** wird verwendet. Die frühere ASCII-only-Vorgabe ist durch den ausdrücklichen Nutzerwunsch ersetzt; das Copyrightzeichen wird nicht mehr durch eine ASCII-Umschreibung verdrängt.

Bedienung in Design 2:

- **Full / Compact / Minimal** wechseln die Informationsdichte, nicht die Trading-Strategie.
- **Overview / Checks / Performance** gliedern die ausführliche Ansicht. Bei knappem Platz werden Inhalte paginiert.
- Gekürzte Texte behalten ihren vollständigen Inhalt im nativen Tooltip. Kürzung oder eine reduzierte Ansicht bedeutet nicht, dass ein Gate bestanden wäre.

Preis-, Range-, Order- und Positionsmarkierungen verwenden tatsächlich vorliegende Daten. Es werden keine Orders erfunden, fehlende Historie nicht als Nullgewinn ausgegeben und kein ungebundenes Accountbudget als verfügbare Verlustreserve dargestellt. Geplantes Risiko ist keine Renditeprognose. Die zusätzliche [Pending-Demonstration](C:/QM/repo/docs/ops/evidence/2026-09-07_strategy_console_v2/design_2_pending_synthetic_fixture.png) ist ausdrücklich eine synthetische No-Trade-Testansicht, kein echter Auftrag dieses Accounts.

## Grenzen und offene Arbeit

Der abschließende Stand besteht 814 lokale Tests und zehn native Prüfsuiten. Der direkte Wechsel am Original-EA sowie Full → Compact → Minimal → Full funktionieren ohne EA-Neustart. Die Größenprüfung auf dem No-Trade-Testchart hat den MT5-Rundungsfall tatsächlich durchlaufen. Der temporäre Testchart wurde anschließend geschlossen, seine Nachweise bleiben erhalten. Die vollständigen Nachweise einschließlich des zuvor fehlgeschlagenen und anschließend korrigierten QA-Zoom-Testaufbaus liegen im [technischen Releasebericht](C:/QM/repo/docs/ops/evidence/2026-09-07_strategy_console_v2/README.md).

Alle 45 geladenen Inputs wurden über einen unabhängigen nativen Export geprüft. Gegenüber dem vorherigen V2-Stand änderte sich nur die angezeigte Build-Kennung; Risiko bleibt 0,3125 %, RISK_FIXED bleibt 0, Portfolio-Gewicht bleibt 1. Neun andere FTMO-EA-Binärdateien, Factory-EX5 und AutoTrading-Einstellungen sind unverändert. Vor und nach der Installation wurden keine offenen Positionen oder Orders auf dem Account beobachtet. Die Installation selbst hatte ein dokumentiertes Neuinitialisierungsfenster; die anschließenden Design-Klicks nicht.

Native Vergleichs- und Layoutprüfungen belegen weder ein perfektes Design für jede Fenstergröße noch Strategierobustheit, Profitabilität oder FTMO-Payoutfähigkeit. Live-Aufnahmen sind nicht atomar, die automatische Pixelmessung zertifiziert keine Zeit-/Preis-Overlay-Geometrie. Der Demo-Server allein beweist keine bestimmte Vertragsphase.

Die priorisierten Folgearbeiten sind separat festgehalten: [FTMO-Ausführungsvertrag und Nachqualifikation](C:/QM/repo/docs/ops/evidence/2026-09-07_strategy_console_v2/ftmo_execution_followup.md) sowie [zwei Transferfehler und kontrollierter Retry-Folgeauftrag](C:/QM/repo/docs/ops/evidence/2026-09-07_strategy_console_v2/transfer_errors_followup.md). **Die Factory bleibt OFF, bis die Dropbox→Drive-Kopie einschließlich Abschlussprüfung belegt fertig ist.** Dieser Handoff erteilt keine Trading- oder Betriebsfreigabe; Website, Marketplace und Build-in-public bleiben vertagt.
