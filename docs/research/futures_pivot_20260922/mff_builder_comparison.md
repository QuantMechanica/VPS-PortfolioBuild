# Ergänzung: MFFU Builder 50k gegenüber Rapid EOD 50k

Stand 22.09.2026, öffentliche Primärquellen. Österreich ist bestätigter Wohnsitz; Staatsangehörigkeit bleibt offen. Keine Kontakte, Registrierungen, Käufe oder Tests ausgeführt. Die vorhandenen `prop_firms.md/json` wurden nur gelesen: Builder war dort nicht als eigener Kandidat modelliert.

**Rapid EOD bleibt vorläufig erste Wahl; Builder Default kommt als günstigerer Forschungskandidat hinzu.** Das ist keine Rangliste nach nachgewiesenem Erwartungswert. Für beide fehlen Futures-Strategieergebnisse und die ausdrückliche Freigabe unserer Hetzner-Ausführung. MFFU erlaubt eigene konfigurierte Algorithmen grundsätzlich; daraus folgt keine bestimmte Hosting- oder API-Berechtigung. [Automation](https://help.myfundedfutures.com/en/articles/8444599-fair-play-and-prohibited-trading-practices)

## Vergleich auf gleicher $2.000-Verlustgrenze

| Merkmal | Builder Default 50k | Rapid EOD 50k |
|---|---|---|
| Einmalige Liste / sichtbare Aktion | $153 / $92 bei 40%; alternativ $107 bei 30% | $209 / $125 |
| Aktionsbedingung | 40%-Preis ausdrücklich höchstens zweimal nutzbar | aktuelle Homepage-Aktion; Checkout bestätigen |
| Aktivierung | $0 | $0 |
| Evaluation: Ziel / EOD-Abstand | $3.000 / $2.000 | $3.000 / $2.000 |
| Evaluation: Tage / Best-Day | mindestens 1 / keine Consistency | mindestens 4 / höchstens 30% |
| DLL, Evaluation und SIM | $1.000 Soft-Pause | keines |
| SIM-News | erlaubt | Tier-1-News verboten |
| SIM-Auszahlung | 80%, 50% Best-Day, mindestens 2 Handelstage je Zyklus; erster Antrag nach 48 Stunden | 90%, keine Best-Day-Regel; täglich, frühestens 24 Stunden nach erstem Trade und erfüllten Gewinnregeln |
| Mindestrequest / Cap | $500 / $2.000 je Zyklus, höchstens 5 SIM-Payouts | $500 / kein Einzelrequest-Cap |

Preise: [Builder-Guide](https://help.myfundedfutures.com/en/articles/14290805-builder-plan-50k-a-comprehensive-guide), [aktuelle Planseite](https://myfundedfutures.com/). Evaluation: [offizielle Vergleichstabelle, 21.08.2026](https://help.myfundedfutures.com/en/articles/11802636-traders-evaluation-simplified). SIM und Auszahlung: [Payoutübersicht](https://help.myfundedfutures.com/en/articles/13745661-payout-policy-overview-best-and-fastest-prop-firm-payouts), [Rapid EOD](https://help.myfundedfutures.com/en/articles/16158363-rapid-eod-50k-a-comprehensive-look).

Der sichtbare Builder-Preis **$75** gehört zur Variante mit **$1.500 MLL**, Listenpreis $125; deren 30%-Preis lautet $87. Er ist kein Preis für den Default mit $2.000 Abstand. Keine Aktivierung, aber VAT, Reset, Plattform-/Live-Datenkosten und Auszahlung/FX sind damit nicht vollständig gebunden. [Builder-Preistabelle](https://help.myfundedfutures.com/en/articles/14290805-builder-plan-50k-a-comprehensive-guide)

## Vollständige erste Cashhürde: eigene Rechnung

Annahmen: ein erfolgreicher Versuch, Handelsgewinne bereits netto nach modellierten Handelskosten, keine zusätzlichen Programm-/Datenkosten, Steuern oder FX. Request bezeichnet den Kontodebit vor Profit-Split. Evaluationsertrag wird nicht ausgezahlt.

| Fall | Eval + SIM-Gewinn vor erstem $500-Request | Cash nach Split | Nach Aktionsgebühr / Listenpreis | Restsaldo minus Verlustboden |
|---|---:|---:|---:|---:|
| Builder Default | $3.000 + $2.600 = $5.600 | $400 | $308 / $247 | $2.100 − $100 = $2.000 |
| Rapid EOD, konservative Pufferlesart | $3.000 + $2.600 = $5.600 | $450 | $325 / $241 | $2.100 − $100 = $2.000 |
| Builder $1.500-Variante | $3.000 + $2.100 = $5.100 | $400 | $325 / $275 | $1.600 − $100 = $1.500 |

Builder verlangt ausdrücklich $500 **oberhalb** des $2.100- bzw. $1.600-Puffers. Die Payoutübersicht setzt den Boden nach der ersten Builder-Auszahlung auf +$100. Rapid bleibt sprachlich weniger eindeutig; unser Modell lässt $2.100 stehen. Sollte Rapid einen $500-Request bereits bei insgesamt $2.100 erlauben, wären danach nur $1.500 Verlustspielraum übrig. Diese Alternative ist ungeklärt und wurde nicht als zulässig unterstellt. [Builder-FAQ](https://help.myfundedfutures.com/en/articles/14290805-builder-plan-50k-a-comprehensive-guide), [Payoutübersicht](https://help.myfundedfutures.com/en/articles/13745661-payout-policy-overview-best-and-fastest-prop-firm-payouts), [Rapid-Regeln](https://help.myfundedfutures.com/en/articles/16158363-rapid-eod-50k-a-comprehensive-look)

Bei gleichem erfolgreichen Mindestrequest spart Builder Default $33 Startgebühr, verliert jedoch $50 durch den niedrigeren Anteil: deshalb $17 weniger erster Netto-Cash. Zum Listenpreis liegt Builder im Beispiel $6 vorn. Fehlversuche, Promoablauf und unterschiedliche Erfolgswahrscheinlichkeiten können die Rangfolge verändern. Diese Rechnungen schätzen weder Wahrscheinlichkeit noch Dauer einer Auszahlung.

Ein eigener Pfadvergleich muss die Gewinnverteilung berücksichtigen: $1.800 bester SIM-Tag bei insgesamt $2.600 ergibt rund 69,2%. Builder benötigt bei unverändertem Best-Day mindestens $3.600 Gesamtgewinn, also $1.000 zusätzlich. Umgekehrt würde ein $1.800-Evaluationstag bei Rapid wegen 30% mindestens $6.000 Eval-Gesamtgewinn verlangen; Builder hat dort keine solche Hürde. Die Mindesttage alleine entscheiden daher nicht.

## Regelkonflikt und begrenzte Empfehlung

Builder formuliert zur Breach-Prüfung: “Open equity losses are counted when determining whether your account has breached the rule at the end of the trading day.” Die allgemeine EOD-Erklärung nennt dagegen das Unterschreiten durch eine offene Position als Fail. Sie behauptet außerdem allgemein, es gebe kein Tageslimit, obwohl Builder eines nennt. Das ist keine belastbare Ausnahme zugunsten einer lockeren Intraday-Ausführung. [Builder-Text](https://help.myfundedfutures.com/en/articles/14290805-builder-plan-50k-a-comprehensive-guide), [allgemeine EOD-Erklärung](https://help.myfundedfutures.com/en/articles/8348565-end-of-day-eod-drawdown-explained)

**Vorgeschlagene konservative Modellierung:** Boden nur nach Sessionabschluss nachziehen; jede Intraday-Equity-Berührung oder -Unterschreitung des bereits geltenden Bodens als Verletzung behandeln. Zusätzlich Builder-DLL als Soft-Pause führen. Dies ist eine eigene strengere Annahme, keine bestätigte Implementierung der Firma. Exakte Gleichheits-, DLL-, Session- und Durchsetzungsregeln müssen vor Produktbindung bestätigt werden. Keine Lockerung aus dem widersprüchlichen Satz ableiten.

Builder Default wäre nach geklärter Ausführungsberechtigung besonders prüfenswert, wenn Eval-Consistency oder SIM-News-Sperren die Strategie begrenzen und ihre tatsächlichen Tagesergebnisse mit 50% SIM-Consistency und $1.000 DLL zurechtkommen. Rapid bleibt der Vergleich für höheren Anteil, fehlende SIM-Consistency und höhere einzelne Requests. Die $1.500-Variante wird nicht allein wegen $17 Ersparnis gegenüber Builder Default bevorzugt: sie reduziert den Verlustspielraum um $500.

Builder erlaubt nur ein aktives SIM-Konto. Nach fünf genehmigten Auszahlungen folgt laut Plan die Live-Berechtigung: höchstens $10.000 SIM-Debit beziehungsweise $8.000 Cash bei fünf ausgeschöpften Caps, keine Zusage dieses Ergebnisses. Live nennt 80%, tägliche Payouts, $250 Minimum, $1.000 DLL und EOD-Boden bis null. Der Guide klärt den Übertrag verbleibender SIM-Gewinne nicht ausreichend; Rapid-Reserveregeln dürfen nicht übertragen werden. Die allgemeine +$100-Formulierung ebenfalls nicht stillschweigend auf Builder Live anwenden. [Builder-Live-Tabelle](https://help.myfundedfutures.com/en/articles/14290805-builder-plan-50k-a-comprehensive-guide), [separater Rapid-Live-Pfad](https://help.myfundedfutures.com/en/articles/13134718-understanding-rapid-live)

Folgearbeit: Builder Default und Rapid EOD anhand derselben vorher festgelegten MES-/MNQ-Signale durch vollständige Evaluations-, SIM-, Payout- und Live-Zustände vergleichen. Geringere Gebühr ist belegt; besserer Erwartungswert bleibt unbewiesen. Keine Kaufentscheidung aus diesem Nachtrag.
