# Begrenzter unabhängiger Review: prop_risk.py

Stand 2026-09-22. Geprüft wurden `tools/futures_lab/prop_risk.py`, dessen neun vorhandene Tests und README im Worktree `D:/QM/worktrees/codex-futures-pivot-20260922`. Keine Strategie, Providerzertifizierung oder Handelsverbindung wurde getestet; keine gemeinsame Datei geändert. Ein rein synthetischer Eingabe-Reproducer wurde ausgeführt.

## Behebbarer False-Pass

**P2: Python-Eingaben können Handelstage durch eine Zahl statt Boolean vervielfachen.** `Point.traded` ist nur annotiert. `session_traded |= point.traded` (Zeile 105) und `sum(d['traded'] ...)` (Zeile 123) übernehmen beispielsweise den Wert 4. Eine einzige abgeschlossene Session mit $3.000 Gewinn, `traded=4`, `minimum_trading_days=4` und ausgeschalteter Best-Day-Regel ergibt tatsächlich `CONDITIONS_MET`. Die CSV-Schicht weist solche Werte bereits zurück; direkt erzeugte `Point`-Objekte umgehen diese Prüfung. Für einen späteren Engine-Adapter ist dies eine reale Fehlklassifikation.

Empfehlung: alle drei Point-Flags `end_of_session`, `traded`, `flat` auf exakten Boolean-Typ prüfen, nicht mit `bool(value)` normalisieren. Zahlen und Strings zurückweisen; gezielter Regressionstest. Befund mit minimalem In-Memory-Beispiel reproduziert und an Root gemeldet.

## Grenzen, bereits korrekt dokumentiert

- Intraday-Breaches bleiben nach Erholung gespeichert; EOD-Boden und Intraday-Equity-Trailing sind getrennt. Exakte Bodenberührung wird konservativ als Verletzung behandelt. Zeitreihenfolge, unvollständiger Sessionabschluss und nicht endliche Beträge werden zurückgewiesen. Hier fand ich keinen zusätzlichen arithmetischen False-Pass.
- Sessionlabels, `traded` und Vollständigkeit der Equity-Extrema sind vom Adapter gelieferte Behauptungen. Vier beliebige Sessionlabels innerhalb eines Tages wären kein Nachweis für vier echte Providertage. README verlangt ausdrücklich einen gebundenen Providerkalender; ein späterer Adapter muss das erfüllen und seine Datenabdeckung nachweisen.
- `CONDITIONS_MET` bezeichnet den ersten historischen Bedingungstreffer innerhalb der gelieferten Evaluationsstrecke. Eine spätere Verletzung macht die ganze Strecke FAILED. Das ist im README erklärt; keine Live-/Funded- oder Auszahlungsberechtigung daraus ableiten.
- `payout_diagnostic` prüft ausdrücklich nur einen unveränderten, vom Aufrufer übergebenen Boden. Tradeify-Flex-Erstauszahlung kann ihn sofort auf Start+$100 setzen. Wer den alten Boden übergibt, erhält rechnerisch zu viel Spielraum; die Funktion meldet Providerberechtigung aber korrekt als `NOT_EVALUATED`. Vor firmenspezifischem Einsatz braucht es einen separaten Lifecycle-Adapter einschließlich Floor-Reset, Mindestrequest, Anteil, ausstehendem Antrag und Transfer.

Der diagnostische Umfang ist für Offline-Vorbereitung passend. Nach Behebung des Boolean-Befunds entsteht daraus weiterhin keine Zertifizierung für MFFU, Tradeify oder einen anderen Anbieter.

## Nachprüfung: Befund behoben

Read-only-Nachprüfung am 22. September 2026: Der oben beschriebene Boolean-False-Pass ist behoben. `Point.__post_init__` verlangt für `end_of_session`, `traded` und `flat` jeweils `type(value) is bool`; andere Werte erzeugen `ValueError`. Die Sessionaggregation verwendet jetzt logisches `or` statt bitweisem `|=`. Damit kann `traded=4` bei regulärer Point-Erzeugung nicht mehr vier Handelstage vortäuschen.

SHA-256 der nachgeprüften `D:/QM/worktrees/codex-futures-pivot-20260922/tools/futures_lab/prop_risk.py`:

`6815fe6623713b7717687bbd54a5419308c6f2329b9334c8e698fc07de550b97`

Der gelesene Regressionstest deckt alle drei Flags mit jeweils `1`, `4`, `'false'` und `None` ab, insgesamt zwölf ungültige Kombinationen. Roots gelesene Belege `risk_tests.json` und `risk_tests.txt` melden zehn Tests erfolgreich, Exitcode 0, Laufzeitpunkt `2026-09-22T10:29:04.388753+00:00`. Kein erneuter Testlauf durch den Reviewer; Code und vorhandener Testnachweis wurden geprüft. Die oben dokumentierten Grenzen des generischen Diagnosemoduls bleiben bestehen.
