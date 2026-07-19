# FTMO Challenge EA Book V3 — technischer Buchvertrag 2026-07-17

## Entscheidung

Für einen zügigen, aber nicht überhebelten FTMO-Durchlauf wird kein großes Sammelbuch benötigt. Zielbild sind fünf Rollen mit höchstens einem Champion je Ertragsfamilie:

1. EURUSD SessionFlow als täglicher Dichtemotor,
2. USDJPY Gotobi als kalendarischer FX-Effekt,
3. genau ein Aktienindex-Microstructure-Champion,
4. Turn-of-the-Month als seltener, eigenständiger Indexeffekt,
5. genau ein langsamer Trend-/Metall-Diversifikator.

Das operative Ziel sind 50–65 ausführbare, kostenbereinigte Trades je 20 Handelstage. Das ist kein Renditeversprechen. Das Book wird erst für einen Challenge-Kauf freigegeben, wenn die gemeinsame Out-of-Sample- und Monte-Carlo-Prüfung eine mediane Phase 1 von höchstens 50 Handelstagen und Phase 2 von höchstens 30 Handelstagen bei den unten definierten Risikolimits zeigt.

Aktueller Zustand: Buchdesign und Risiko-State-Machine sind vollständig, die operative Freigabe bleibt `RESEARCH ONLY / CHALLENGE NO-GO`. SessionFlow ist als QM5_4006 gebaut, scheitert aber vor Strategiebewertung an der EURUSD-History-Synchronisierung auf T1–T4. Der reparierte QM5_12969-Gotobi-Vertrag hat einen frischen deterministischen Q02-PASS und befindet sich im vorregistrierten Q03. QM5_4007 MAC5 hat Strict Build bestanden, ist aber in einem gültigen deterministischen Q02 mit 0/0 Trades terminal gescheitert und aus dieser Buchfassung ausgeschlossen. Der zentrale Governor V2 ist für Build-Tests freigegeben, nicht für Live. Damit bleibt aktuell kein Alpha-EA challenge-ready.

## Gewähltes FTMO-Modell

Vorgesehen ist FTMO 2-Step Swing von Anfang an. Die Swing-Variante ist notwendig, weil Overnight- und D1-Rollen Teil des Books sind und ein Standardkonto später nicht in Swing umgewandelt werden kann. Nach den am 2026-07-17 geprüften FTMO-Regeln gelten:

- Phase 1: 10 % Profit Target,
- Verification/Phase 2: 5 % Profit Target,
- mindestens vier Handelstage je Phase, kein maximales Zeitlimit,
- Maximum Daily Loss: 5 % des Anfangssaldos, Neuberechnung um 00:00 CE(S)T einschließlich offenem P/L, Kommissionen und Swaps,
- Maximum Loss: 10 % des Anfangssaldos,
- Profit Target zählt erst bei geschlossenen Positionen,
- der Best-Day-Mechanismus gehört zum 1-Step-Modell, nicht zum gewählten 2-Step-Modell.

Offizielle Regelquellen:

- https://ftmo.com/en/trading-objectives/
- https://ftmo.com/faq/ftmo-swing-account-type/
- https://ftmo.com/faq/which-instruments-can-i-trade-and-what-strategies-am-i-allowed-to-use/
- https://ftmo.com/de/forbidden-trading-practices/

## Die fünf EA-Rollen

### 1. EA_EURUSD_SessionFlow — Hauptmotor

Zweck: hohe natürliche Signaldichte ohne Scalping, Grid oder künstlich erhöhte Positionsgröße.

Mechanischer Entwurf:

- nur EURUSD auf M5/M15-Ausführung,
- europäische Teilstrecke: short ab 07:00 europäischer Ortszeit bis 08:00 New-York-Zeit,
- US-Teilstrecke: anschließend long von 08:00 bis 16:00 New-York-Zeit,
- beide Teilstrecken werden intraday geschlossen; keine Übernachtfinanzierung,
- maximal eine Position gleichzeitig; die zweite Teilstrecke beginnt erst nach bestätigtem Close der ersten,
- keine Stundenoptimierung: die beiden Zeitfenster sind vorab fest,
- explizite IANA-/DST-Logik für Europa und New York; die europäischen/US-amerikanischen DST-Mismatch-Wochen sind eigene Testsegmente,
- Skip bei geschlossenem Referenzmarkt, abnormalem Spread, fehlenden Bars oder nicht eindeutig auflösbarer Zeitzone,
- keine Verlustprogression, kein Nachkaufen, kein Grid.

Erwartete Rohfrequenz: 38–42 Teilstrecken je 20 Handelstage; nach Feiertags- und Ausführungsfiltern weniger.

Phase-1-Risikovorschlag nach Review: 0,25 % je Teilstrecke und höchstens 0,50 % realisierter Familienverlust pro Strategietag. Beide Teilstrecken sind für Tages- und Clusterlimits eine gemeinsame Strategiequelle und dürfen nicht als zwei unabhängige Risiken gezählt werden.

Falsifikation vor Zulassung:

- 2015–2026 mit aktuellen FTMO-Spreads, Kommissionen und Slippage sowie 2x-Kostenstress,
- getrennte Auswertung der DST-Mismatch-Wochen,
- 08:30-New-York-Makrotermine, Feiertage und Spreadspitzen separat,
- feste Regeln auf EURUSD; kein nachträgliches Ausweichen auf das beste Währungspaar,
- Stability-, Parameter-Perturbation-, Walk-forward- und Execution-Reconciliation-PASS.

Primäre Forschungsthese: lokale Teilnehmer erzeugen während ihrer eigenen Handelszeit systematische Orderflow-Ungleichgewichte. Freigegebene und vollständig extrahierte Primärquelle:

- Breedon und Ranaldo, Intraday Patterns in FX Returns and Order Flow, 2013: https://doi.org/10.1111/jmcb.12032
- Autorenfassung: https://www.qmul.ac.uk/sef/media/econ/research/workingpapers/2012/items/wp694.pdf

Die Card `strategy-seeds/cards/fx-session-flow_card.md` ist APPROVED; QM5_4006 und Magic 40060000 sind gebunden. Stop-, DST-, Restart-/Exit-, Freitag- und Grenzzeit-Kostenverträge sind vor dem Build eingefroren. Strict Compile/Build besteht mit 0 Fehlern und 0 Warnungen. Q02 bleibt dennoch `INFRA_FAIL_UNDECIDABLE`: vier physische Terminals endeten vor gültigen Bars mit `EURUSD.DWX: history synchronization error`. Leere 0-Trade-Reports zählen weder als PASS noch als Strategieversagen. Der EA wird erst nach einem gültigen Model-4-Q02 erneut betrachtet.

### 2. QM5_12969 USDJPY Gotobi — kalendarischer FX-Anker

Zweck: ein von SessionFlow verschiedener, japanischer Kalendereffekt mit geringer bisher gemessener Buchkorrelation.

Designentscheidung:

- die bereits definierte Gotobi-Regel unverändert verwenden; keine neue Variante und kein Parameter-Mining,
- USDJPY, etwa 5–6 Trades pro Monat,
- Phase-1-Risiko 0,30 % je Signal,
- zusammen mit SessionFlow höchstens 0,50 % offenes FX-Clusterrisiko.

Aktuelle Vertrag-v2-Evidenz vom 2026-07-17 für den eingefrorenen EX5-Hash `933d63c0…7673be4`:

- strikter Compile- und Build-Check PASS,
- frischer T1-Q02 Model 4, 2017–2022, exakt zwei deterministische Läufe: je 213 Trades, PF 1,57, Netto 6.062,13 und Drawdown 1,89 %,
- frühere, noch nicht auf die spätere Q03-Auswahl übertragbare Re-Costing-Vorevidenz: aktuelle FTMO-Kosten PF 1,421 / Netto 4.559,80 und 2x-Kommissions-/Swapstress PF 1,365 / Netto 4.024,11.

Das ist noch keine Challenge-Zulassung. Der frühere Card-/Runtime-Widerspruch ist geschlossen: 120 Pips ist der genehmigte nicht-alpha Katastrophenstop; `[60, 90, 120, 150, 180, 240, 360]` ist die einzige Q03-Achse. Die Preregistration ist an Card, MQ5, EX5 und Set gebunden. Erst der Plateau-Median wird eingefroren; Q04–Q10 und FTMO-Kostenbelege müssen danach auf genau derselben Binary/Set-Lineage neu entstehen.

### 3. Equity Microstructure Champion — genau ein EA

Zweck: Der Equity-Baustein soll im Regelfall 12–20 Trades pro Monat aus einem liquiden Aktienindexeffekt liefern. Mehrere Index-EAs mit ähnlichem Timing würden nur Scheindiversifikation erzeugen. Die MAC5-D1-Reserve ist ausdrücklich davon ausgenommen: Wegen des kausalen Sign-only-Target-Retain-Vertrags werden 4–10 abgeschlossene Trades pro Monat akzeptiert, sofern mindestens 336 Trades in 2018–2024 und mindestens 36 in jedem Volljahr erreicht werden. Sie ist dann Diversifikator, nicht Geschwindigkeitsmotor.

Adjudizierter Stand:

1. QM5_1159 Overnight-MA20 ist ausgeschlossen: Q05 PF 1,07 bei 17,09 % Drawdown und keine saubere Q04-Lineage.
2. QM5_10326 Closing-Auction-Reversal ist nicht entscheidungsfähig: Proxy/Card und Q02-Infrastruktur sind ungeklärt.
3. QM5_4007 Index-MAC5-Reversal bestand Card-Review und Strict Build, scheiterte aber im gültigen Model-4-Q02 deterministisch mit 0/0 Trades. Der konkrete v1-Build ist terminal ausgeschlossen; die Rolle bleibt unbesetzt.

MAC5-Reserve-Regel:

- tägliche Indexrenditen r1 bis r4,
- Signal m = 4*r1 + 3*r2 + 2*r3 + r4,
- konträre Sign-only-Zielrichtung am nächsten Tagesanker aus -m; keine ex-post Varianz- oder Signalstärken-Skalierung,
- tägliche Target-delta-Prüfung: gleiche Richtung hält unveränderte Lots und den ursprünglichen 2xATR-Stop; Exit nur bei Flip, Flat/Invalid, Stop oder verspätetem Restart,
- diese Card autorisiert ausschließlich `SP500.DWX` als Forschungssymbol; eine spätere FTMO-Route zu `US500.cash` hätte vollständig neu qualifiziert werden müssen.

Q02-Urteil:

- zwei valide deterministische Reports mit jeweils 0 Trades, PF 0,00 und Netto 0,00,
- wiederholte Orderablehnungen am exakten Broker-D1-Anker mit `[Market closed]`, nachdem der One-shot-Versuch bereits persistiert war,
- Zero-Trade-Kohorte 1/5, weil keine weiteren Symbole autorisiert sind,
- nach `qm-zero-trades-recovery` daher `FAIL_ZERO_TRADES_BELOW_COHORT_NO_DISPATCH`: kein stiller Code-Fix, kein v2 und keine Q03-Promotion.

Die Root-Cause-Akte liegt unter `framework/EAs/QM5_4007_index-mac5-rev/ZT_RootCause_QM5_4007_20260717.md`. Das ist ein Execution-Lifecycle-Fehlschlag dieser Binary, kein positiver oder negativer Nachweis der Papier-These.

Freigegebene MAC5-Primärquelle:

- Baltussen, van Bekkum und Da, 2019: https://doi.org/10.1016/j.jfineco.2018.07.016
- Autorenfassung: https://personal.eur.nl/vanbekkum/2018%20JFE%20BaltussenVanBekkumDa.pdf

Phase-1-Risiko des zugelassenen High-Frequency-Champions: 0,25–0,30 %. Die MAC5-D1-Reserve bleibt wegen Wochenend-Gaps und täglicher Kostenbindung bei 0,15 %. Gesamtes Aktienindex-Clusterrisiko einschließlich Turn-of-the-Month höchstens 0,45 % gleichzeitig. QM5_1159, QM5_10326 und MAC5 dürfen nicht parallel als drei Buchbausteine laufen.

### 4. QM5_20004 Turn-of-the-Month Index D1 — seltener Diversifikator

Zweck: ein transparentes Monatswechselmuster, das weder vom täglichen FX-Flow noch vom normalen Overnight-Regime abhängt.

Festes Regelbild:

- T ist der letzte Handelstag des Monats,
- long zum Close von T-1,
- Exit zum Close des dritten Handelstags des neuen Monats,
- US500 und DE40 als Primärkandidaten, UK100 als Challenger,
- am Ende nur der robuste Champion, ungefähr ein Trade pro Monat,
- Phase-1-Risiko 0,30–0,35 %, aber Aktienclusterlimit 0,45 % hat Vorrang.

Die vollständige McConnell/Xu-TOM-Extraktion ergab eine exakte Duplikation der bestehenden QM5_1049/QM5_20004-Regel. Der neue Entwurf wurde deshalb terminal als `REJECTED_DUPLICATE` beendet: keine neue ID, kein zweiter Build und kein künstlicher Diversifikator. QM5_20004 bleibt alleiniger Referenzkandidat, ist aber ohne aktuelle kanonische Q02–Q10-Lineage nicht zugelassen.

Primärquellen:

- McConnell und Xu, 2008: https://doi.org/10.2469/faj.v64.n2.11
- Etula et al., 2020: https://academic.oup.com/rfs/article/33/1/75/5494694

### 5. Slow Diversifier Champion — genau ein EA

Zweck: eine langsamere, nicht intraday-getriebene Quelle für Stressphasen. Sie liefert nicht die Challenge-Geschwindigkeit und darf deshalb nur ergänzen.

Die Rolle bleibt nach dem read-only Evidenzaudit ausdrücklich unbesetzt. QM5_12382 besitzt nur schwache Q02-Vorevidenz, ungültige Q04-Aggregate, einen `GER40`/`GDAXI.DWX`-Widerspruch und nicht gebundene Binary-Hashes. QM5_10377 zeigt zwar auf XAU D1 61 Trades und PF 1,826, aber Q02 und Q04 nutzten verschiedene Binaries, die Card nennt H4 statt D1 und die Frequenz beträgt nur 7,6 Trades/Jahr. QM5_10513 zeigt 76 Trades und PF 1,289, scheitert aber an Cost/Frequency, während das tatsächliche Q04-F2 PF 0,782 liefert. Keiner erhält eine künstliche Champion-Freigabe.

QM5_12897 XAG D1 ist aus dem Ziel-Book ausgeschlossen: der aktuelle FTMO-Kostenlauf scheitert mit 89 Trades, PF 0,555 und Netto -12.514,99. Ein unveränderter Wiederholungslauf wäre kein Erkenntnisgewinn.

Nur einer der beiden wird zugelassen. Ziel sind etwa 1–2 Trades pro Monat bei 0,25–0,30 % Phase-1-Risiko. Alle Trendmärkte zählen bei gemeinsamer Richtung als eine Familie, nicht als unabhängige EAs.

TSMOM-Primärquelle:

- Moskowitz, Ooi und Pedersen, 2012: https://doi.org/10.1016/j.jfineco.2011.11.003
- Autorenfassung: https://research-api.cbs.dk/ws/portalfiles/portal/58851003/time_series_momentum_lasse_heje.pdf

## Was ausdrücklich nicht in das Ziel-Book kommt

- kein Re-Use des alten Round25-Free-Trial-Books und keine Rückkehr zu etwa 9 % offenem Risiko,
- keine zusätzlichen Gold-/Index-Klone; bereits 89 von 144 Kandidaten liegen in diesen beiden Konzentrationen,
- kein Grid, Martingale, Averaging-down oder deadline-getriebenes Hochskalieren,
- keine gleichzeitige Zulassung der drei Equity-Microstructure-Kandidaten,
- kein Carry-EA ohne echte Broker-Swap-Historie,
- kein News-/Latency-/Feed-Exploit, keine Hyperaktivität und keine korrelierte Überexponierung,
- kein Crisis-Hedge als Kern-EA, wenn die Qualifikationsfrequenz unter dem Mindestniveau bleibt.

## Drei Risikogänge

Alle Tageswerte werden wie bei FTMO ab 00:00 CE(S)T auf Equity-Basis einschließlich offenem P/L, Kommissionen und Swaps gerechnet. Der zentrale Risk Governor kann jede EA-Freigabe überstimmen.

| Modus | Risiko je Signal | Max. offenes Bruttorisiko | New-entry halt | Interner Tages-Notausstieg | Interner Gesamt-Floor |
|---|---:|---:|---:|---:|---:|
| Phase 1 | 0,25–0,30 %, TOM max. 0,35 % | 1,00 % | -0,90 % | -1,25 % | -6,00 % |
| Phase 2 | 70 % der Phase-1-Größe | 0,70 % | -0,65 % | -0,90 % | -4,00 % |
| Funded bis erster Reward | 0,10–0,15 % | 0,45 % | -0,35 % | -0,50 % | -2,50 % |

Zusätzliche Progress-Locks:

- Phase 1 ab +7,5 %: alle neuen Risiken um 25 % reduzieren; ab +9,0 % um 50 %; Ziel nur flat verbuchen.
- Phase 2 ab +3,5 %: um 30 % reduzieren; ab +4,5 % um 60 %.
- Funded: Ziel der ersten 14 Kalendertage ist Kapitalerhalt plus positiver Nettostand, nicht ein zweites 10-%-Rennen.
- Keine Risikoerhöhung bei Rückstand gegenüber dem Zeitplan.
- Bei zwei Signalen derselben Familie gilt das strengere Clusterlimit, nicht die Summe vermeintlich unabhängiger Budgets.

Ein Notausstieg ist wegen Gaps und Slippage keine garantierte Verlustobergrenze; deshalb liegen die internen Schwellen weit innerhalb der FTMO-Grenzen.

## Geschwindigkeits- und Wirtschaftlichkeitsvertrag

Die Geschwindigkeit soll aus Frequenz und belastbarer Netto-Expectancy kommen. Zwei Rechenanker:

- 50 Trades × 0,30 % Risiko × 0,20 R netto = ungefähr 3,0 % Erwartungswert pro 20 Handelstage.
- 60 Trades × 0,30 % Risiko × 0,30 R netto = ungefähr 5,4 % Erwartungswert pro 20 Handelstage.

Nur das zweite Niveau unterstützt grob Phase 1 in 6–10 Wochen und Phase 2 in 3–5 Wochen. Mit den frühestens 14 Kalendertagen bis zur ersten Reward-Anfrage ergibt sich ein Zielkorridor von ungefähr 11–17 Wochen ab Challenge-Start. Das ist ein Freigabeziel, keine Zusage. Zeigt die robuste Simulation nur etwa 3 % pro Monat, ist eher mit 14–26 Wochen zu rechnen; dann muss vor dem Kauf entschieden werden, ob Challenge-Gebühr und VPS-Laufzeit wirtschaftlich sind.

Go-live-Gates für das Gesamtbook:

- jeder Champion: striktes aktuelles Q02–Q08 und Q10 PASS, gleiche Binary wie im Test, Stream-/Trade-Reconciliation PASS,
- mindestens zwei voneinander unabhängige Rollen hart qualifiziert, bevor überhaupt eine Portfolio-Simulation als entscheidungsfähig gilt,
- 50–65 ausführbare Trades je 20 Handelstage nach Filtern, nicht nur theoretische Rohsignale,
- aktuelle FTMO-Kosten plus 2x-Kostenstress; keine positive Entscheidung aus Mid-Price-Ergebnissen,
- gewichtete OOS-Nettoexpectancy mindestens 0,25 R; für den schnellen Korridor mindestens 0,30 R,
- gemeinsame Monte-Carlo-Simulation: Median Phase 1 höchstens 50 Handelstage, Median Phase 2 höchstens 30 Handelstage,
- normale und adverse Portfolio-MAE müssen die internen Floors mit ausreichendem Abstand respektieren; vor der Simulation werden Breach-Grenzen festgeschrieben,
- alle FTMO-Ziele werden auf geschlossenen Positionen geprüft,
- wirtschaftlicher Preflight mit Challenge-Gebühr, tatsächlichem VPS-Monatspreis und simuliertem Time-to-first-reward.

Wenn ein Zeit-Gate nicht besteht, wird zuerst der schwache EA ersetzt oder das Book nicht gestartet. Das Risiko wird nicht erhöht, um eine gewünschte Kalenderzahl zu erzwingen.

## Phase 2 und erster Reward

Phase 2 ist kein identischer Neustart: Das Ziel halbiert sich von 10 % auf 5 %, daher sinkt das Signalrisiko auf 70 %. Nach dem Funded-Übergang wird nochmals deutlich reduziert.

Nach der aktuellen FTMO-FAQ kann die erste Reward-Anfrage am 14. Kalendertag nach dem ersten Trade oder später gestellt werden, sofern das Konto positiv ist und alle Positionen sowie Pending Orders geschlossen sind. Das bedeutet nicht, dass exakt zwei jeweils positive Handelswochen vorgeschrieben sind. Für FTMO 2-Step gilt aktuell ein 80-%-Reward-Split; die Challenge-Gebühr wird mit dem ersten Reward zurückerstattet.

Offizielle Quellen:

- https://ftmo.com/de/faq/wie-zahle-ich-meine-gewinne-aus/
- https://ftmo.com/de/faq/werden-noch-weitere-kosten-anfallen-sind-die-kosten-fortlaufend/

## Nächste kontrollierte Entscheidungen

1. Gotobi-Q03 abschließen, Median einfrieren und Q04–Q10 auf derselben Binary/Set-Lineage neu erzeugen.
2. SessionFlow-History-Sync außerhalb der EA-Logik reparieren und den unveränderten Build erneut Q02 prüfen.
3. Equity-Microstructure und Slow Diversifier nur mit neuer oder vollständig identitätsgebundener Evidenz besetzen; MAC5 v1, QM5_12897 und ein TOM-Duplikat bleiben ausgeschlossen.
4. Governor-Liveblocker und produktive Client-Verdrahtung schließen.
5. Erst mit mindestens zwei unabhängigen Pipeline-Champions die gemeinsame synchronisierte Portfolio-/Monte-Carlo- und VPS-Wirtschaftlichkeitsrechnung durchführen.

Bis zu diesen Gates bleiben Challenge-Kauf, Deployment und AutoTrading ausdrücklich gesperrt.
