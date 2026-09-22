# Databento eingerichtet und MES-Datenpilot geliefert

Stand: 2026-09-22T13:23:00.928932+00:00. Dieser Nachtrag aktualisiert die Vorbereitung vom selben Tag; die frueheren Preisabfragen und Zwischenbefunde bleiben unveraendert erhalten.

**Vom OWNER ist aktuell kein weiterer Databento-Klick erforderlich.** Historische Abrufe funktionieren ueber den lokal geschuetzten API-Zugang. Die Chrome-Erweiterung und eine Desktop-App werden dafuer nicht benoetigt. Der Key wurde aus der bereitgestellten Datei verschluesselt uebernommen, mit dem produktiven Lader geprueft und die Klartextdatei danach entfernt. Der Screenshot selbst sowie Anschrift/Zahlungsdetails wurden nicht ins Repository kopiert.

## Tatsachlicher Stand

- Billing-Screenshot vor Abruf: $125 Credits, $0 Rechnungsbetrag, Usage-based aktiviert, keine laufenden Datenplaene. Keine Kontoklassifikation, Lizenzvereinbarung, Zahlungsdaten oder Subscription durch den Agenten geaendert.
- Fuenf begrenzte historische Requests einschliesslich zwei winziger Statusdiagnosen. Angebotswert zusammen **$1.389075271785**, gerundet **$1,39**, innerhalb der $2-Credits-Allokation. Erwarteter Rest bei diesen Preisen: rund **$123,61**; spaeterer Portal-/Rechnungssaldo nicht erneut ausgelesen.
- MESZ6-Session 15.09.2026 22:00 UTC bis 16.09.2026 21:00 UTC. Definition bestaetigt $5/Indexpunkt und 0,25 Indexpunkte je Tick, also **$1,25/Tick**.
- Alle **10.357.657 MBP-1-Records** gelesen: Recordanzahl und Recordbytes stimmen exakt mit dem Angebot ueberein; Dateihash stimmt mit dem Downloadbeleg. Zwei Definitionen und drei tatsaechliche Statusrecords sind erhalten.
- Begrenzter nativer Nautilus-Import: 1.000 Rohrecords ergeben 1.000 Quotes und 182 Trades; alle verglichenen Preis-, Mengen-, Identitaets- und Zeitfelder stimmen. Das ist kein kompletter nativer Tages-Replay und kein Strategiebacktest.
- **71 Tests bestanden.** Originaldaten bleiben unveraendert auf D:, rund 790.23 MiB einschliesslich Diagnose, mindestens 60 GiB Factory-Reserve gewahrt.

## Erkannte und behandelte Datenbesonderheiten

Die Definitionen benoetigen den UTC-Mitternachtssnapshot. Der Preispruefer erweitert deshalb nur deren Startzeit; das Handelsfenster bleibt unveraendert. Die tatsaechlichen Schemafenster sind im Requesthash enthalten. Allgemeine API-Warnungen bleiben blockierend.

Die Status-Metadaten nannten zunaechst 12 Records, die genaue Session enthielt drei. Zwei getrennte UTC-Tagesdateien lieferten je sechs Records; zeitgefiltert ergibt ihre unveraenderte Recordfolge exakt die urspruenglichen drei Records. Fuer **diese konkreten Tage/Dateien** ist die Abweichung damit erklaert: die Status-Metadaten verhalten sich wie Tageszaehlungen. Der Validator akzeptiert nur den expliziten, dateigebundenen Nachweis; andere Count-Abweichungen werden weiterhin abgewiesen. Das ist keine Aussage ueber den internen Herstellerindex oder unabhaengig bewiesene CME-Feed-Vollstaendigkeit.

Der erste Kursrecord enthaelt einen **gekreuzten BBO**. Nautilus uebernimmt ihn unveraendert. Ein spaeterer Ausfuehrungsadapter muss diesen nicht ausfuehrbaren Quote sichtbar ausschliessen; weder Rohdaten noch Pruefzahlen wurden dafuer bereinigt. Native Quote-/Trade-Zeitstempel entsprechen hier `ts_recv`; der originale Exchange-Zeitstempel ist fuer Latenzpruefungen getrennt zu bewahren. Die Definitionen tragen erwartete aeltere Exchange-Zeitstempel ihrer Mitternachtssnapshots.

## Einordnung und naechster Schritt

Der technische Pilot ist geliefert, mit ausdruecklichen Qualitaetsflags. Keine Orders, keine Prop-Challenge, keine Aussage ueber Profitabilitaet. Zunaechst folgen der Ausfuehrungsadapter mit diesen Datenregeln sowie vorab festgelegte Strategieversuche und versionierte Prop-Regelprofile. Weitere Daten werden gezielt bepreist; der Pilot ist kein Ersatz fuer mehrere Marktphasen, Roll-/DST-/Feiertagspruefungen oder einen unberuehrten Ergebnistest.

CME-Kontext: [Kontrakt und Tick](https://www.cmegroup.com/articles/faqs/frequently-asked-questions-micro-e-mini-equity-index-futures.html), [Rollkalender](https://www.cmegroup.com/trading/equity-index/rolldates.html), [Globex-Kalender](https://www.cmegroup.com/trading-hours.html), [Abschaffung der alten Nachmittagspause](https://www.cmegroup.com/notices/electronic-trading/2021/06/20210621.html). Das Fenster entspricht 17:00 bis 16:00 Chicago/CDT; der reguläre Roll war am 14.09., der 16.09. hat keinen geplanten Feiertags-Early-Close. Tatsaechliche Handelsunterbrechungen werden dadurch nicht ausgeschlossen.

## Belege

- [Gesamtergebnis und Hashmanifest](D:/QM/reports/research/futures_pivot_20260922/databento_pilot_result_20260922.json)
- [Vollstaendige technische Validierung](D:/QM/reports/research/futures_pivot_20260922/databento_pilot_validation_20260922.json)
- [Status-Abgleich mit zwei UTC-Tagen](D:/QM/reports/research/futures_pivot_20260922/databento_status_utc_day_reconciliation_20260922.json)
- [Native Stichprobe](D:/QM/reports/research/futures_pivot_20260922/databento_native_sample_20260922.json)
- [Testlauf](D:/QM/reports/research/futures_pivot_20260922/databento_pilot_tests_20260922.json)

Die beiden frueheren Einzelreports tragen zeitlich korrekt noch den damaligen BLOCKED-Status. Dieser Nachtrag und die abschliessende Vollvalidierung dokumentieren den anschliessend erbrachten Statusabgleich; die frueheren Belege wurden nicht umgeschrieben.
