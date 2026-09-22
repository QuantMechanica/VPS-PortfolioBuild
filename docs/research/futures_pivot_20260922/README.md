# Futures-Prop-Vorbereitung für QuantMechanica

**Aktueller Nachtrag vom 22.09.:** Databento-Zugang eingerichtet, echter MES-Pilot
mit 10.357.657 Kursrecords und 71 bestandenen Tests geliefert. Angebotswert inklusive
Diagnose rund $1,39 aus dem bestaetigten Startguthaben; Statuszaehlung fuer die
konkreten Dateien geklaert, ein unbrauchbarer Eroeffnungsquote markiert.
[Pilotbericht und naechste Schritte](D:/QM/reports/research/futures_pivot_20260922/databento_pilot_20260922.md).
Die folgende urspruengliche Vorbereitung bleibt als zeitlich datierter Stand erhalten.

Stand: 2026-09-22T11:35:09.081447+00:00. OWNER-Wohnland: Österreich. Ziel: ein wirtschaftlich tragfähiger Weg bis zur tatsächlichen Auszahlung; noch kein nachgewiesener Futures-Ertrag.

**Entscheidung:** kostenloser NautilusTrader/Python-Kern für reproduzierbare Backtests, Databento-Historie nach Verbrauch, später NinjaTrader 8 als bevorzugter Ausführungsadapter, sofern der konkrete Prop-Vertrag diesen Weg erlaubt. Zunächst MES, danach MNQ. MyFundedFutures Rapid EOD ist der vorläufige erste Anbieter, Tradeify Select Flex die Alternative. Beide bleiben bis zur Klärung ihrer konkreten Betriebsbedingungen bedingte Kandidaten.

## Tatsächlich erledigt

- Isolierte Python-3.11-Umgebung auf `D:/QM/venvs/futures_lab` installiert; NautilusTrader 1.221.0 und 14 Abhängigkeiten versions- und SHA256-gebunden. Diese Version passt zum vorhandenen Python; neuere Releases benötigen eine gesonderte Migration. Keine bestehende Python-/MT5-Umgebung ersetzt.
- Technischer Smoke PASS: 8.725 echte CME-Snapshot-Deltas verarbeitet. Getrennt davon ein synthetischer Roundtrip mit korrekt berechnetem ES-Tickwert, Spreadverlust und Gebühren. Zwei Wiederholungen lieferten gleiche Ereignis-/Fillhashes. Der Snapshot enthält einen Zeitpunkt und ist ausdrücklich kein wirtschaftlicher Backtest.
- Generischen Offline-Risikoprüfer für intraday/EOD-Trailing, Verlustboden, Handelstage, Konsistenz und Auszahlungsspielraum erstellt. 10 Tests PASS; ein im unabhängigen Review gefundener Boolean-Fehler wurde behoben und nachgeprüft. Firmenspezifische Phasenwechsel sind noch nicht als fertig validierter Simulator ausgegeben.
- Maskierte lokale Schlüsseleingabe mit Windows-Benutzerverschlüsselung sowie einen begrenzten Databento-Preisprüfer erstellt. Gesamtsuite: 28 Tests PASS, darunter 16 reine Offline-Tests der Preisabfrage und zwei DPAPI-Tests mit synthetischen Daten. Persönliche Registrierung/Zugangseinrichtung und tatsächliche Datenabfrage sind separate Schritte.
- C: hat 22.49 GiB frei; D: 91.50 GiB. 23.519 historische Dateien (33.26 GiB logisch) sind vollständig in zwei getesteten Archiven (2.76 GiB) erhalten; jede Datei wurde aus dem Archiv per SHA256 und vor Entfernung nochmals an Original und Rückhalteordner geprüft. Die Archivierung erhöhte den beobachteten freien C:-Platz um 17.95 GiB. Separat brachte ausschließlich regenerierbarer npm-Downloadcache 1.82 GiB. C:/QM/archive bleibt für neue Factory-Ausgaben nutzbar; historische Inhalte haben explizite Restore-Mappings. Keine CFD-Strategie oder Ergebnisdatei wurde ohne erhaltene, verifizierte Archivkopie entfernt. Auf D: wurden separat 18.74 GiB regenerierbare Tester-Caches entfernt; alle zehn Worker wurden wiederhergestellt. Der Rohbeleg dokumentiert korrigierte Zähl-/Relaunchprobleme und eine außerhalb des Löschumfangs verkürzte aktive T5-Logdatei; 75 von 76 alten Logpräfixen blieben gleich.
- Fünf konkrete Factory-Folgeaufträge sind angelegt: lizenzierter Datentest, datierte Anbieterprofile, vorab festgelegte Strategieversuche, spätere Holdout-/Auszahlungspfadprüfung und der zusätzliche Builder-Tarifvergleich. Der letzte Datenbankabgleich steht im [Statusbeleg](<D:/QM/reports/research/futures_pivot_20260922/followup_state_check.json>); abhängige Aufträge bleiben bis zur Erfüllung ihrer Voraussetzungen gesperrt.
- Von mir veranlasste neue Gebühren: **$0**. Keine Challenge oder kostenpflichtige Daten/Software erworben, keine Orderverbindung aktiviert. Der OWNER hat die persönliche Databento-Registrierung begonnen; verfügbarer Zugang und Guthaben sind noch nicht bestätigt.

## Anbieterwahl und Österreich

| Anbieter | Bewertung für uns | Entscheidender Punkt |
|---|---|---|
| MyFundedFutures Rapid EOD 50k | Vorläufig erste Wahl | Eigene Automation erlaubt; $2.000 EOD-Abstand in Evaluation und SIM. Hosting auf unserem Hetzner-Rechner, konkrete Connectorrechte und Gebühren noch bestätigen. |
| MyFundedFutures Builder 50k Default | Günstigerer Vergleichstarif | Ebenfalls $2.000 EOD-Abstand, aber $1.000 Tagesverlustpause, 50%-SIM-Konsistenz und 80%-Anteil. Widersprüchliche Breach-Formulierung konservativ behandeln. |
| Tradeify Select Flex 50k | Alternative | Eigene/exklusive Bots erlaubt; VPS laut FAQ nach normalem Login möglich, genauer Login-/Reconnectweg und Eigentumsbedingungen offen. |
| Topstep | Lokaler Fallback | Bots erlaubt, Serverorders/VPS verboten; ProjectX-API steht nicht für Live Funded zur Verfügung. |
| TradeDay | Lokaler Fallback | Eigene ATS erlaubt, VPS verboten. Auszahlungs-/Drawdownregeln unterscheiden sich erheblich nach Produkt. |
| Earn2Trade | Zurückgestellt | Eigene Automation/Hosting nicht ausreichend belegt; kleine Auszahlungen und Live-Datengebühren können teuer sein. |
| Apex / Take Profit Trader | Für unsere Automation ausgeschieden | Die untersuchten aktuellen Regeln verbieten den gewünschten automatisierten Orderweg. |

Österreich steht bei MFFU/Tradeify nicht auf den untersuchten Verbotslisten. Das ersetzt keine persönliche KYC-Prüfung; Staatsangehörigkeit und Datenlizenzstatus werden nicht aus dem Wohnland abgeleitet. Quellen und offene Widersprüche stehen im [vollständigen Anbieterabgleich](<D:/QM/reports/research/futures_pivot_20260922/prop_firms.md>).

Primärbelege: [MFFU Automation](https://help.myfundedfutures.com/en/articles/8444599-fair-play-and-prohibited-trading-practices), [MFFU Rapid EOD](https://help.myfundedfutures.com/en/articles/16158363-rapid-eod-50k-a-comprehensive-look), [Tradeify Bot-Bedingungen](https://help.tradeify.co/en/articles/10468318-guidelines-for-traders), [Tradeify VPS-FAQ](https://help.tradeify.co/en/articles/12268494-common-faqs), [Topstep API-/Serverregeln](https://help.topstep.com/en/articles/11187768-topstepx-api-access).

## Kostenoptimierter Einstieg

1. **Jetzt $0 Softwarekosten:** vorhandener Rechner plus installierter Batchkern. NinjaTrader-Analyse/Simulation ist laut Hersteller kostenlos; die konkrete Prop-Verbindungs-/Lizenzberechtigung wird separat geprüft. Kein teures Lifetime-Paket für den Prototyp.
2. **Historische Daten gezielt beziehen:** Databento bewirbt $125 Startguthaben für berechtigte neue Teams. Historische Daten sind ohne Monatsabo nach Verbrauch verfügbar. Erst einen MES-Kontrakt/Handelstag bepreisen, dann bei erfolgreichem Import erweitern. Unser vorgeschlagenes erstes Barausgabenlimit für Daten ist $50; es ist kein bereits bewilligter Download und keine Zusage, dass damit jede gewünschte Historie abgedeckt wird. [Databento Preise](https://databento.com/pricing)
3. **Erst danach eine einzige Challenge:** sichtbarer MFFU-50k-Aktionspreis $125, Liste $209; Tradeify Select 50k $165. Keine bezahlte Reset-Serie, keine Kontovervielfachung und kein laufendes $199-Datenabo für den ersten historischen Versuch. Preise/Steuern/Plattformberechtigungen vor Kauf erneut prüfen. [MFFU Preise](https://myfundedfutures.com/), [Tradeify Preise](https://help.tradeify.co/en/articles/14369021-tradeify-pricing-reference)

Bekannte Grundkosten wären damit bei $50 zusätzlicher Datenausgabe beispielsweise $175 für MFFU zum Aktionspreis oder $259 zum Listenpreis; Tradeify $215. Nicht gebundene Pflichtgebühren, VAT, FX und Auszahlungsgebühren sind darin nicht enthalten. Der endgültige Gesamtpreis ist vor Zahlung im Checkout und im Plattformvertrag zu binden.

Der zusätzlich geprüfte MFFU Builder 50k **Default mit $2.000 MLL** kostet laut Guide $153 Liste bzw. $92 bei der begrenzten 40%-Aktion (zwei Nutzungen): mit $50 Daten wären das $142 bekannte Grundkosten. Der $75-Einstieg auf der Homepage betrifft dagegen die $1.500-MLL-Variante. Bei identischem ersten $500-Request bleiben nach 80%-Anteil und $92 Gebühr $308, bei Rapid nach 90%-Anteil und $125 Gebühr $325, jeweils ohne weitere Kosten. Welcher Tarif die bessere Auszahlungserwartung hat, ist damit nicht bewiesen; beide gehören auf dieselben späteren Handelspfade. [Vollständiger Builder-/Rapid-Vergleich](<D:/QM/reports/research/futures_pivot_20260922/mff_builder_comparison.md>) und [offizieller Builder-Guide](https://help.myfundedfutures.com/en/articles/14290805-builder-plan-50k-a-comprehensive-guide).

Sierra Chart ist die günstige integrierte Reserve (Historienpaket ab $26/Monat), falls ein belegter Daten-/Connectorvorteil entsteht. LEAN/Docker, Quantower und MultiCharts bringen für unseren ersten Schritt zusätzliche Einrichtung oder Kosten; der [Vergleich von sechs Plattformen](<D:/QM/reports/research/futures_pivot_20260922/software_data.md>) dokumentiert die Gründe und Datenbeschränkungen.

## Was ein belastbarer Backtest braucht

- Tatsächliche MES/MNQ-Einzelkontrakte mit Instrumentdefinitionen, Last sowie Bid/Ask; kein CFD-Alias als Futures-Ergebnis. ES/NQ können ein getrennt geprüftes Signal liefern, ersetzen aber keine Micro-Ausführungshistorie.
- Festgelegtes Rollover-Mapping, UTC-Rohzeit, New-York-Cashsession und Chicago-Handelstag mit DST und Feiertagen/frühen Schlüssen. Backadjustierte Preise sind keine Fillpreise.
- Kommissionen, Börsen-/Routingkosten, Slippage, Latenz und konservative Stop-/Limitfills. Ein berührtes Limit ist kein garantierter Fill. Daten-/Brokergebühren gehören zusätzlich in die reale Cashrechnung.
- Kleine vorab fixierte Kandidatenmenge: höchstens zwei unterschiedliche Intraday-Hypothesen und sechs anfängliche Symbol-/Variantenarme. Alle Versuche protokollieren; Trainings-, Validierungs- und unberührte Teststrecke vorab festlegen. Overnight-Systeme wie Turnaround Tuesday benötigen eine eigene Prüfung gegen das tägliche Flat-Gebot.
- Frühere CFD-Forschung zählt zur Auswahlhistorie: Futures-Daten über bereits untersuchte Indexzeiträume sind nicht automatisch ein unberührter Markt-Holdout. Ein erstmals getesteter Datensatz und ein tatsächlich ungesehener Marktzeitraum sind zu unterscheiden; prospektive Sim-Beobachtung bleibt erforderlich.
- Intraday markierte Equity bis durch Evaluation, SIM, Auszahlung und gegebenenfalls Live-Transfer. EOD-Trailing bestimmt, wann der Verlustboden steigt; der vorhandene Boden darf trotzdem intraday nicht verletzt werden.
- Eine kostengestresste, zeitlich getrennte Prüfung, danach Signal-/Orderparität mit der erlaubten Ausführungsplattform und beobachteter Simbetrieb. Ein positiver Profit Factor oder ein bestandener Techniktest alleine genügt nicht.

Der aktuelle Risikoprüfer bildet einen bewusst begrenzten Teil davon ab. Newsverbote, Inaktivität, exakte Auszahlungskriterien, Phasewechsel und vollständige Handelskalender müssen in den datierten Anbieterprofilen ergänzt werden. Für eine geschätzte Wahrscheinlichkeit oder Dauer bis zum Cashout fehlen uns derzeit echte Futures-Strategieergebnisse.

## Warum der früheste Cashout nicht automatisch das beste zweite Einkommen ist

Rechenbeispiele, **keine Ertragsprognosen**: Bei MFFU konservativ erst $3.000 Evaluationsgewinn und danach $2.600 SIM-Gewinn. Ein $500-Request ergäbe bei 90% Anteil $450 vor weiteren Kosten/Steuern; nach $125 Startgebühr $325, wenn sonst keine Ausgaben anfallen. Der verbleibende Puffer wäre $2.000. Die genaue Erstauszahlungs-Pufferformulierung ist noch zu bestätigen.

Tradeify Flex erlaubt nach fünf Gewinntagen ab $150 unter den genannten Bedingungen einen kleinen Erstrequest: bei genau $750 Gewinn und $375 Entnahme bleiben nach 90%-Anteil $337,50 Auszahlung und nur $275 Abstand zum dann angehobenen Verlustboden. Das kann für ein fortlaufendes Einkommen zu wenig sein. Unsere Auswahl soll die Gebühren und den verbleibenden Kontopuffer berücksichtigen. [Explizite Rechnungen und Annahmen](<D:/QM/reports/research/futures_pivot_20260922/cashflow_examples.json>).

## Persönlicher nächster Schritt

[Databento-Registrierung und spätere geschützte Zugangseinrichtung](<D:/QM/worktrees/codex-futures-pivot-20260922/docs/research/futures_pivot_20260922/ONBOARDING.md>) ist vorbereitet. Kein API-Key gehört in den Chat oder in Git. Anschließend kann der kleine lizenzierte Datentest beginnen. Für die Anbieter sind konkrete Hosting-/Lizenzfragen vorbereitet; es wurden keine Nachrichten versendet.

## Evidenz

- [Techniktest und deterministische Wiederholung](<D:/QM/reports/research/futures_pivot_20260922/nautilus_smoke/result.json>)
- [10 Risikotests](<D:/QM/reports/research/futures_pivot_20260922/risk_tests.json>) und [unabhängiger Review einschließlich behobenem Befund](<D:/QM/reports/research/futures_pivot_20260922/prop_risk_review.md>)
- [28 Tests der vollständigen Vorbereitungssuite](<D:/QM/reports/research/futures_pivot_20260922/lab_tests.json>)
- [Erhaltene Strategie-/Ergebniswurzeln](<D:/QM/reports/research/futures_pivot_20260922/preservation_inventory.json>)
- [Speicherabschluss und Prüfsummenbelege](<D:/QM/reports/research/futures_pivot_20260922/storage_final.json>)
- [Tatsächliche Factory-Folgeaufträge](<D:/QM/reports/research/futures_pivot_20260922/followup_receipt.json>)

Der Vault-Gesamtlint meldet unverändert 16 Befunde in anderen Seiten; keine Meldung betrifft die neue Futures-Seite oder den geänderten ToDo-Index. [Lint-Nachweis](<D:/QM/reports/research/futures_pivot_20260922/vault_lint_result.json>).

Diese Vorbereitung beweist die technische Basis. Sie liefert noch keine profitable Futures-Strategie und keinen seriös zusagbaren Auszahlungstermin. CFD-Archiv und negative Befunde bleiben für weitere Forschung nutzbar.
