# Futures Prop: Automation und realer Cashoutpfad

Stand: 22. September 2026. Öffentliche Primärquellen, keine Anbieteranmeldung, Zahlung, Kontaktaufnahme oder Handelsaktion. Wohnland Österreich wurde vom OWNER bestätigt und von Root übermittelt; Staatsangehörigkeit bleibt unbekannt. Budget ohne feste Obergrenze, mit Fokus auf Kosten und erwartete Rendite. Der bestehende QM-Rechner ist laut Root ein Hetzner-Server.

**Für diesen Server sind MyFundedFutures und Tradeify bedingte Kandidaten.** Bei MFFU fehlen belastbare Hosting-/API-Bedingungen; Tradeify verlangt Strategieexklusivität und einen besonderen Login-/VPS-Ablauf. Topstep und TradeDay schließen die vorhandene Serverausführung aus. Apex und Take Profit Trader verbieten die gewünschte Automation. Bei Earn2Trade ist sie nicht ausdrücklich belegt.

| Firma | Eigene Automation | Server/Plattform | Einordnung |
|---|---|---|---|
| MyFundedFutures | ausdrücklich erlaubt, kein HFT/Sim-Fill-Exploit | NinjaTrader/Tradovate u.a.; VPS und rohe API nicht verifiziert | Rapid EOD weiter vorbereiten |
| Tradeify Futures | erlaubt bei alleiniger/exklusiver Nutzung | VPS erst nach normalem Login; NinjaTrader/Rithmic-Routen unterscheiden | Alternative, Exklusivität prüfen |
| Topstep | ProjectX API für SIM erlaubt | persönliches Gerät; kein VPS/VPN/Remote-Orderflow; API nicht Live | nur lokaler Fallback |
| TradeDay | eigene ATS über unterstützte Plattform | keine Plattform-API, VPS verboten | nur lokaler Fallback |
| Earn2Trade | keine eindeutige eigene Botfreigabe gefunden | Kopierer verboten; API/VPS ungeklärt | keine Freigabe ableiten |
| Take Profit Trader | Bots/Algos auf Test/PRO/PRO+ verboten | Plattformfunktion hebt Verbot nicht auf | ausscheiden |
| Apex | manuelle Einzelorder erforderlich | Signaltools/Handelskopierer sind begrenzte Ausnahmen | ausscheiden |

## MyFundedFutures: passendere Regelstruktur, noch kein bestätigter Ausführungsweg

Eigene konfigurierte Algorithmen sind erlaubt; für Live gelten CME-Regeln. Unterstützte Plattformen sind belegt, eine Tradovate-Anmeldung beweist aber keinen eigenständigen REST-API-Zugang. In den geprüften Regeln fand sich keine ausdrückliche VPS-Erlaubnis. Eine generische Unternehmens-Blogpassage über VPS bei Kopierdiensten zählt dafür nicht.

[MFFU Fair Play and Prohibited Trading Practices](https://help.myfundedfutures.com/en/articles/8444599-fair-play-and-prohibited-trading-practices), [MFFU Supported Platforms](https://help.myfundedfutures.com/en/articles/8528335-overview-of-supported-platforms-at-mffu), [MFFU platform connections](https://help.myfundedfutures.com/en/articles/8528337-connecting-to-different-platforms-at-mffu).

Rapid EOD 50k: $3.000 Evaluationsziel, $2.000 EOD-Drawdown, mindestens vier Tage, 30% Best-Day-Regel. SIM: ebenfalls EOD, keine Tagesverlustgrenze, kein Tier-1-News-Trading; der Verlustboden fixiert sich bei +$100. Erstpuffer $2.100, Mindestrequest $500, 90/10, tägliche Antragsmöglichkeit und kein Einzelrequest-Cap. Nachfolgende Requests verlangen $500 neuen Gewinn. Die Formulierung, ob der erste Mindestrequest zusätzlich oberhalb des Puffers liegen muss, bleibt unpräzise; konservativ mit $2.600 SIM-Gewinn rechnen.

[MFFU Rapid EOD50k](https://help.myfundedfutures.com/en/articles/16158363-rapid-eod-50k-a-comprehensive-look), [MFFU payout overview](https://help.myfundedfutures.com/en/articles/13745661-payout-policy-overview-best-and-fastest-prop-firm-payouts).

Die sichtbare 50k-Karte nennt aktuell $125 Aktionspreis statt $209, einmalig und ohne Aktivierung. Die AGB unterscheiden neue Einmalpläne von vor dem 20. August 2026 gekauften Abos. Alte monatliche Preislisten sind daher kein aktuelles Angebotsmodell. KYC und Rise-Vertrag gehen der Bank-/Kryptoauszahlung voraus; sofortige Genehmigung bedeutet keine sofortige Bankgutschrift.

[MFFU current pricing cards](https://myfundedfutures.com/), [MFFU Terms and Conditions](https://myfundedfutures.com/terms), [MFFU first payout process](https://help.myfundedfutures.com/en/articles/11542406-guide-to-your-first-payout-quick-and-easy-process), [MFFU KYC/AML and restricted countries](https://help.myfundedfutures.com/en/articles/9717961-kyc-aml-policies).

Live-Transfer erfolgt nach Risikoteam-Entscheidung oder automatisch bei $10.000 Netto-Tagesgewinn; darüber liegender Tagesgewinn verfällt. Bis $5.000 SIM-Profit werden Reserve. Der Live-50k startet bei null mit $2.000 EOD-Verlustabstand, endet beim statischen Nullboden, zahlt 90% und hat keinen Live-Puffer. SIM-Konten werden ruhend gestellt; parallele SIM-Nutzung ist ausgeschlossen. Hosting, konkrete Live-Plattform und Gebühren sind noch zu binden.

[MFFU Understanding Rapid Live](https://help.myfundedfutures.com/en/articles/13134718-understanding-rapid-live).

## Tradeify Futures: VPS bedingt möglich, eigene Strategie muss exklusiv sein

Eigene Bots sind unter Bedingungen erlaubt: Alleineigentum nachweisbar, keine geteilte Nutzung und derselbe Bot nicht über mehrere Firmen. Ein Video des Starts auf dem eigenen PC kann verlangt werden. Die FAQ erlaubt VPS-Trading nach normalem Login, untersagt aber Login über VPS/VPN. Dieser Ablauf ist für Hetzner noch nicht eindeutig. Auch eine selbst geschriebene Implementierung einer verbreiteten Strategie beweist keine Exklusivität.

[Tradeify Guidelines for Traders](https://help.tradeify.co/en/articles/10468318-guidelines-for-traders), [Tradeify Futures common FAQs](https://help.tradeify.co/en/articles/12268494-common-faqs).

Select 50k kostet $165 einmalig, Reset $109, keine Aktivierung. Evaluation: $3.000 Ziel/$2.000 EOD, 40% Consistency und damit mindestens drei Tage. Flex danach: $2.000 EOD, keine Tagesverlustgrenze, fünf Gewinntage ab $150; maximal 50% des aktuellen Gewinns, seit September maximal $2.500 je Request, 90/10. Die erste Auszahlung kann den Verlustboden sofort auf Start+$100 setzen. Daily stattdessen verlangt $2.100 verbleibenden Puffer, $1.000 Tagesverlustlimit und begrenzt neue 50k-Requests auf $1.250. Beide Wege enden potenziell im Live-Transfer.

[Tradeify Pricing Reference](https://help.tradeify.co/en/articles/14369021-tradeify-pricing-reference), [Tradeify Select Evaluation Accounts](https://help.tradeify.co/en/articles/12853921-select-evaluation-accounts), [Tradeify Select Flex and Daily payouts](https://help.tradeify.co/en/articles/12853966-select-flex-and-select-daily-payout-policies).

Die aktuelle Supportseite nennt NinjaTrader über Tradovate sowie Quantower/Sierra Chart über Rithmic. Ein Unternehmensartikel sagt dagegen NinjaTrader erst ab Elite Live: expliziter Quellenwiderspruch. Ältere FAQ-/Blog-Angaben zur Live-Auswahl werden durch die aktuelle Elite-Seite präzisiert. Nicht Tradeify247/Krypto-Regeln übernehmen. Vertragliche Prüfung kann die beworbene Auszahlungsgeschwindigkeit verlängern.

[Tradeify Supported Platforms](https://help.tradeify.co/en/articles/10468221-supported-platforms), [Tradeify platform article](https://tradeify.co/post/futures-prop-trading-platforms-tradeify), [Tradeify Funded Trader Agreement](https://tradeify.co/funded-trader-agreement), [Tradeify KYC/AML](https://help.tradeify.co/en/articles/11384149-kyc-and-aml-policy).

## Topstep und TradeDay: lokale Ausführung als separate Option

Topstep erlaubt eigene ProjectX-Bots, aber keine Serverorders, Orderrelais oder automatisierten Trigger zum Orderendpunkt. Das API ist im Live-Funded-Konto nicht verfügbar. API kostet $29/Monat bzw. $14,50 mit dokumentiertem Rabatt. 50k-Combine: $49/Monat+$149 Aktivierung oder $95/Monat ohne Aktivierung. Ziel $3.000, EOD-Loss-Limit $2.000; aktuell 55% Consistency, frühestens zwei Tage. Deutschland steht auf der XFA-only-Liste, mit $200.000 Gesamtpayoutgrenze und möglichem Pro-Track.

[TopstepX API Access](https://help.topstep.com/en/articles/11187768-topstepx-api-access), [Topstep Pricing and Payment Questions](https://help.topstep.com/en/articles/14289835-topstep-pricing-and-payment-questions), [Consistency at Topstep](https://help.topstep.com/en/articles/8284208-consistency-at-topstep), [Topstep eligibility](https://help.topstep.com/en/articles/8284116-am-i-eligible-to-trade-with-topstep).

XFA ist Simulation. Standard verlangt fünf Gewinntage ab $150; Consistency drei Tage und 40% Best-Day. 50k-Caps $2.000/$3.000, jeweils höchstens halber Saldo; 90% für neue Teilnehmer. Optionale-DLL-Capverdopplung ist ein zeitlich begrenztes Angebot. Erste Auszahlung setzt den Verlustboden auf null: der Restsaldo ist dann das tatsächliche Risikokapital. Internationaler SWIFT: $30 und genannte 5–10 Geschäftstage nach Prüfung. Live-Auszahlungs- und API-Regeln separat behandeln.

[Topstep Payout Policy](https://help.topstep.com/en/articles/8284233-topstep-payout-policy), [Topstep Maximum Loss Limit](https://help.topstep.com/en/articles/8284204-what-is-the-maximum-loss-limit).

TradeDay lässt ATS nur über unterstützte Plattformen laufen, stellt keine Plattform-API bereit und verbietet gekaufte Drittanbieterbots sowie VPS. Quick Pay 50k zeigt $59 Aktionspreis statt $131 monatlich; Ziel $3.000/$2.000 Drawdown, fünf Tage/30%. Funded Quick Pay trailt **intraday**, auch nach EOD-Evaluation. Frühe Auszahlungen unter $4.000 aktuellem Gewinn werden 50/50 geteilt; nur darüber verbleibende Anteile 80/20. Auszahlungen stoppen das gross-profit-basierte Nachziehen der Verlustgrenze nicht.

[TradeDay Automated, Algo and Bot Trading](https://tradeday.freshdesk.com/en/support/solutions/articles/103000085101-automated-algo-and-bot-trading), [TradeDay VPN/VPS policy](https://tradeday.freshdesk.com/en/support/solutions/articles/103000295384-using-a-vpn-vps-or-ip-masking-add-on), [TradeDay current plan cards](https://www.tradeday.com/), [TradeDay Quick Pay payout policy](https://tradeday.freshdesk.com/en/support/solutions/articles/103000335937-payout-policy).

Fast Pass ist anders: 45% Consistency, EOD in Evaluation und SIM, fünf Gewinntage ab $150, maximal $1.500/50% je Request bei neuen 50k-Konten, 80/20. Erster Request setzt den Boden auf Start; Transfer spätestens beim fünften Request. Derselbe offizielle Artikel nennt zunächst unveränderten $2.000-Live-Drawdown, später ein $1.500-Beispiel plus $500 Schutzpuffer: nicht ungeprüft modellieren. Deutsche Staatsbürger sind von Funded Live ausgeschlossen, dürfen SIM nutzen.

[TradeDay Fast Pass](https://tradeday.freshdesk.com/en/support/solutions/articles/103000405229-what-is-fast-pass-), [TradeDay prohibited countries](https://tradeday.freshdesk.com/en/support/solutions/articles/103000123294-prohibited-countries).

## Earn2Trade: Automation offen, frühe kleine Auszahlungen teuer

Die offiziellen Regeln verbieten missbräuchliche Software/AI, beweisen aber keinen pauschalen Botbann und geben auch keine klare eigene Ausführungsfreigabe. Kopierer sind eindeutig in allen Phasen verboten. Rithmic und NinjaTrader/Tradovate werden angeboten; rohe API und VPS bleiben ungeklärt.

[Earn2Trade prohibited conduct](https://help.earn2trade.com/en/articles/9286647-prohibited-conduct-in-earn2trade-evaluations-and-in-the-livesim-live-trading-environment), [Earn2Trade trade copier policy](https://help.earn2trade.com/en/articles/12034590-am-i-allowed-to-copy-trades-across-multiple-accounts), [Earn2Trade platform selector](https://www.earn2trade.com/purchase).

Gauntlet Mini 50k: $170/Monat, $3.000 Ziel/$2.000 EOD/$1.100 Tagesverlust. Seit Juli kein fester Zehntageszwang mehr, faktisch vier profitable Tage wegen 30%. LiveSim zahlt wöchentlich, ohne zusätzliche Tage/Consistency/Puffer; $139 Aktivierung wird aus dem ersten Gewinnabzug bezahlt. Für 50k gilt bei **jedem einzelnen** Request unter $2.250 nur 50%, ab $2.250 80%. Nicht-US-Rise kostet $50; Mindestnetto $100. LiveSim hat $5.000 Withdrawal-Maximum. Live ersetzt EOD durch Intraday-Equity-Trailing und verlangt $140/$156 monatliche Datengebühr je Exchange (Rithmic/NinjaTrader).

[Earn2Trade Gauntlet Mini](https://www.earn2trade.com/gauntlet-mini), [Earn2Trade evaluation rules](https://help.earn2trade.com/en/articles/5941958-what-are-the-evaluation-rules), [Earn2Trade withdrawal policy](https://help.earn2trade.com/en/articles/5452472-what-is-the-withdrawal-policy), [Earn2Trade funded fees](https://help.earn2trade.com/en/articles/2280137-what-is-the-fee-structure-on-the-live-or-livesim-accounts), [Earn2Trade trailing drawdown](https://help.earn2trade.com/en/articles/3292356-what-is-a-trailing-drawdown).

## Ausschlüsse: Take Profit Trader und Apex

TPT untersagt automatische Ausführung auf Test, PRO und PRO+. Zur Einordnung: 50k kostet $170/Monat, Ziel $3.000, Test-EOD $2.000, seit August drei Tage und unter 50% Consistency. PRO trailt intraday, verlangt $2.000 Puffer und teilt 80/20. Das Werbeversprechen „Tag eins“ ersetzt den Puffer nicht. Die offizielle Consistency-Seite enthält eine widersprüchliche Zielformel; nicht als ausführbare Regel übernehmen. Die Mai-Aktion ohne Aktivierung ist abgelaufen.

[TakeProfitTrader Universal Trading Policies](https://takeprofittraderhelp.zendesk.com/hc/en-us/articles/34431153546397-TakeProfitTrader-Universal-Trading-Policies-UTP), [TakeProfitTrader current plan page](https://takeprofittrader.com/es/control-center/pro), [TakeProfitTrader consistency](https://takeprofittraderhelp.zendesk.com/hc/en-us/articles/15170316538013-Rule-5-Be-Consistent), [TakeProfitTrader PRO rules](https://takeprofittraderhelp.zendesk.com/hc/en-us/articles/15171769361053-PRO-Account-Rules), [TakeProfitTrader PRO withdrawals](https://takeprofittraderhelp.zendesk.com/hc/en-us/articles/15172219527581-PRO-Account-Profit-Split-Withdrawal-Rules), [TakeProfitTrader reset-price update](https://takeprofittrader.com/blog/test-reset-pricing-update-our-biggest-flash-sale-ever-nofee-50).

Apex verlangt manuelle Einzelorders; vorprogrammierte Bots/Orderänderungen sind verboten. Eigene Kontokopierer dürfen nur manuelle Ursprungsorders spiegeln. Neue EOD-50k-PA: SIM, $2.000 EOD, fünf Tage ab $250 Gewinn, unter 50% Best-Day, dauerhaft $2.100 Sicherheitspuffer, mindestens $500 Request; Startberechtigung bei $2.600 Gewinn. 100% Split, sechs Caps: $1.500/$1.500/$2.000/$2.500/$2.500/$3.000; anschließend schließt die PA. Der dynamische Preis wurde nicht zuverlässig extrahiert. Legacy- und neue Bedingungen nicht vermischen.

[Apex User Agreement](https://dashboard.apextraderfunding.com/agreement/user-agreement), [Apex prohibited activities](https://apextraderfunding.com/help-center/uncategorized/prohibited-activities/), [Apex EOD Performance Accounts](https://apextraderfunding.com/help-center/eod-trailing-drawdown-accounts/eod-performance-accounts-pa/), [Apex EOD payouts](https://apextraderfunding.com/help-center/eod-trailing-drawdown-accounts/eod-payouts/), [Apex current product homepage](https://apextraderfunding.com/).

## Cash-Rechenbeispiele, keine Ertragsprognosen

| Annahme nach bestandenem Test | Tatsächlicher Zahlungseingang vor Steuern | Danach verbleibender Verlustspielraum |
|---|---|---|
| MFFU Rapid EOD: $2.600 SIM-Gewinn, davon $500 Request | $450; abzüglich sichtbarer $125 Startgebühr = $325 | $2.100 Saldo minus $100 Boden = $2.000 |
| Tradeify Flex: fünfmal $150 = $750, halber Gewinn entnommen | $337,50; minus $165 Startgebühr = $172,50 | $375 Restsaldo minus $100 Boden = nur $275 |
| Topstep Standard lokal: $2.000 SIM-Gewinn, $1.000 Request | $900 minus $30 SWIFT; minus $49+$149+$14,50 Gebühren = $657,50 | $1.000 Restsaldo bei Nullboden |

Die angenommenen Handelsgewinne sind netto nach bereits modellierten Handelskosten; diese nicht doppelt abziehen. Zusätzliche Daten-/Plattformgebühren, ungemessene Slippage, Wechselkurs und Steuern sind nicht vollständig gebunden. Eval-Gewinn wird nicht ausbezahlt: beim konservativen MFFU-Beispiel stehen zunächst $3.000 Eval plus $2.600 SIM-Gewinn vor $450 Brutto-Cash. MFFU-Buffersemantik bleibt die oben genannte offene Detailfrage. EOD bedeutet, dass der Boden am Tagesende steigt; eine Verletzung des vorhandenen Bodens kann trotzdem intraday erfolgen. Nominales „50k“ ist keine $50.000 frei verfügbare Risikokasse.

Nächste bindbare Vorbereitung: einen Futures-Ausführungsadapter und MES/MNQ-Risikorechner ohne Kontoanschluss entwickeln; Drawdown, Puffer, News, Payout-Abzug und Live-Transfer je Produkt als getrennte Zustände führen. Vor einer späteren Anbieterwahl fehlen Staatsangehörigkeit, Vertragsstatus als Privatperson/Firma, die bedingten Hosting-/API-Nachweise sowie die noch ungebundenen Kostenbestandteile. Keine Profitabilität oder schnelle Auszahlung ist aus einer Mindesttageangabe ableitbar.

Datierung: Abrufstand ist eindeutig; viele Help-Center zeigen lediglich relative Änderungszeiten. Kurzfristige Angebote sind Momentaufnahmen. Alte Artikel, Blogwerbung, Affiliate-Listen und aktuelle Produktverträge können abweichen; im JSON sind Quellen, Widersprüche und ungebundene Felder ausdrücklich erfasst.


## Österreich, Kosten und abschließende Detailprüfung

Österreich fehlt in den aktuellen MFFU- und Tradeify-Ausschlusslisten. Das ist ein positiver Wohnlandbefund, keine Zusage zur Staatsangehörigkeit, KYC, Auszahlung oder späteren Live-Brokerannahme. Bei Tradeify kann eine Live-Ablehnung außerdem die Rückkehr zu SIM ausschließen. Die im Vergleich erläuterten Deutschland-Regeln werden nicht pauschal auf den österreichischen Wohnsitz übertragen.

[MFFU KYC/AML and restricted countries](https://help.myfundedfutures.com/en/articles/9717961-kyc-aml-policies), [Tradeify restricted countries](https://help.tradeify.co/en/articles/10495888-rules-restricted-countries), [Topstep eligibility](https://help.topstep.com/en/articles/8284116-am-i-eligible-to-trade-with-topstep), [TradeDay prohibited countries](https://tradeday.freshdesk.com/en/support/solutions/articles/103000123294-prohibited-countries).

| Kosten bis zum ersten Payout, ohne gescheiterten Versuch | MFFU Rapid EOD 50k | Tradeify Select 50k |
|---|---|---|
| Einmalige Evaluationsgebühr | $125 sichtbare Aktion / $209 Liste | $165 |
| Aktivierung | $0 | $0 |
| Ein zusätzlicher Versuch | Resetpreis offen; zwei neue Käufe zusammen $250 bei gleicher Aktion bzw. $418 Liste | $274 zusammen mit einem $109-Reset; zwei neue Käufe $330 |
| MES/MNQ pro Kontrakt und Roundtrip | $1,90 | $1,82 |
| ES/NQ pro Kontrakt und Roundtrip | $4,68 | $5,76 |
| VAT, Auszahlung/FX, optionale Daten/Software | nicht vollständig gebunden | nicht vollständig gebunden |

Die Kommissionen sind Anbieterlisten, keine gemessenen Ausführungskosten; Slippage kommt hinzu. MFFU berechnet im Live-Konto professionelle CME-Daten, Plattformgebühren und Kommissionen aus dem Kontosaldo, ohne im geprüften Artikel einen vollständigen Monatspreis zu nennen. Tradeify bietet L1 bei erfüllter Non-Professional-Vereinbarung; die Preisseite warnt sonst vor möglichen $300 monatlich. Das ist kein verifizierter allgemeiner Elite-Live-Tarif. Für Österreich wurde weder pauschal 20% VAT hinzugefügt noch Steuerfreiheit angenommen: Checkout/Vertragsstatus fehlen.

[MFFU current pricing cards](https://myfundedfutures.com/), [MFFU futures instruments and round-trip costs](https://help.myfundedfutures.com/en/articles/9735811-futures-instrument-list), [MFFU Live Funded costs](https://help.myfundedfutures.com/en/articles/10101257-understanding-live-funded-account-at-myfunded-futures), [Tradeify Pricing Reference](https://help.tradeify.co/en/articles/14369021-tradeify-pricing-reference), [Tradeify trading commission fees](https://help.tradeify.co/en/articles/10468315-trading-commission-fees).

Die Tradeify-Tabelle bestätigt **$250 Mindestrequest auch für Flex**. Der $375-Request im Beispiel liegt darüber; $337,50 nach Split und $172,50 nach einer $165-Gebühr sind unter den genannten Annahmen korrekt. Nach einem zusätzlichen Reset bleiben nur $63,50 vor weiteren Kosten. Beim MFFU-Beispiel ergibt der Listenpreis statt Aktionspreis $241 anstelle von $325. Genehmigung, Guthaben in Rise und Geldeingang auf dem Bankkonto sind drei getrennte Ereignisse; Rise nennt zusätzliche Banklaufzeit, lokale Währung ist regionsabhängig.

[Tradeify Select Flex and Daily payouts](https://help.tradeify.co/en/articles/12853966-select-flex-and-select-daily-payout-policies), [Tradeify Rise payout process](https://help.tradeify.co/en/articles/12844518-rise-payouts-main-payout-method).

Aktueller Tradeify-Elite-Pfad: früheste Auswahlprüfung nach drei Payouts eines Kontos oder zehn insgesamt, ohne automatische Zusage. Wird der Transfer angeordnet, ist er verpflichtend; alle SIM/Evaluationskonten schließen. Gewinne seit dem letzten erfolgreichen Payout werden nicht übertragen. Elite beginnt bei null, 50k mit $2.000 EOD-Drawdown und 80/20 statt SIM-90/10; der Boden fixiert bei +$100. Payouts vor Fixierung warten auf die EOD-Anpassung und verkleinern anschließend den Verlustspielraum. Auszahlung bis auf null schließt das Konto. Diese Mechanik gehört in jede Cashout-Simulation; ein dauerhaftes SIM-Modell überschätzt den Pfad.

[Tradeify Elite Program](https://help.tradeify.co/en/articles/12969284-tradeify-elite-program).
