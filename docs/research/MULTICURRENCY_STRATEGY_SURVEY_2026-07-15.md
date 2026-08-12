# Multicurrency-Strategien für QuantMechanica V5

**Auftrag:** OWNER, 2026-07-15  
**Lane:** Codex Research / Engineering  
**Status:** `RESEARCH MEMO / NO BUILD / NO MT5 TERMINAL / NO T_LIVE`  
**Evidenzstand:** 2026-07-15  
**Geltungsbereich:** genereller Survey, Systematik, V5-Fit und Kandidaten für eine spätere G0/Q00-Entscheidung  
**Nicht autorisiert:** neue EA-ID, Strategy Card, Codeänderung, Build, Backtest, Pipeline-Lauf, MT5-Terminal oder Live-Aktion

---

## Executive Verdict

1. **„Multicurrency“ ist keine eigenständige Alpha-Klasse.** Es beschreibt, dass Signal, Risiko oder Ausführung mehrere Währungspaare gemeinsam verwenden. Der eigentliche Return-Treiber muss weiterhin benannt werden: Momentum, Trend, Carry, Value, Mean Reversion, Event-/Regime-Prämie usw.

2. **28 FX-Paare sind keine 28 unabhängigen Wetten.** Ein verbundenes Universum aus acht Währungen besitzt nur sieben unabhängige Währungsrichtungen. Paarpositionen müssen deshalb auf Währungs-Nodes aggregiert werden; sonst können mehrere scheinbar verschiedene Trades dasselbe USD-, JPY- oder AUD-Risiko mehrfach hebeln.

3. **Die beste erste Forschungsrichtung ist ein langsamer, node-basierter FX8-Momentum-Benchmark.** Vorgeschlagen werden zwei sauber präregistrierte Familienvergleiche:

   - cross-sectional Momentum mit sechs Monaten Formation und monatlichem Rebalance;
   - time-series/absolute Trend mit zwölf Monaten Formation und monatlichem Rebalance.

   Beide haben belastbare Literatur, benötigen im Kern nur synchronisierte Preise und reale Kosten und passen besser zu DarwinexZero als kurzlebige Mehrbein-Arbitrage. Es existieren jedoch bereits eng benachbarte Lineages (`QM5_10717`, `QM5_1111`, `QM5_12614`, außerdem Currency-Strength-Baskets). **Daher zuerst Lineage-Reconciliation, keine neue Card und keine neue ID.**

4. **Carry und Value sind wichtige Diversifikatoren, aber derzeit Datenprojekte.** Carry ist ohne historische, point-in-time Long-/Short-Swaps oder Forward-Discounts nicht valide testbar. Heutige Broker-Swaps rückwirkend zu verwenden ist kein historisches Signal. Value benötigt point-in-time REER/CPI-/Makro-Vintages. Ein Price-Momentum-Signal darf nicht als „Carry-Proxy“ umetikettiert werden.

5. **Keine neue Cointegration-Suchwelle.** Die interne sign-aware Frontier wurde bereits breit durchsucht; die Überlebenden scheiterten später überwiegend an Q04/Q05. `QM5_13117` ist trotz früherer Q02–Q07-Evidenz nach frischem Annual-Density-/Recency-Befund `RESEARCH_ONLY_NO_GO`, nicht pipeline-ready.

6. **Explizite No-Gos:** H1-Lead/Lag, kurzfristige cross-sectional FX-Reversion, Dreiecksarbitrage, generische „Currency Strength“ ohne separaten Return-Treiber sowie neue Pair-/Filter-/Kalman-/PCA-Mining-Wellen.

7. **Vor einem Multicurrency-Lauf ist eine Governance-Klärung nötig.** Der spezifische Basket-Vertrag verlangt genau ein logisches Work Item und eine kombinierte Basket-Equity; ein älterer Prozess verlangt noch Symbol-Fan-out. Ebenso ist die aktuelle Mindestfrequenz „pro Symbol“ für rotierende Selektionsbaskets nicht eindeutig. Dieses Memo empfiehlt die logische Basket-Einheit, ratifiziert sie aber nicht.

## 1. Was „Multicurrency“ technisch bedeutet

### 1.1 FX als Graph statt Paarliste

Für ein Währungspaar `A/B` gilt für synchrone Spot-Logreturns näherungsweise:

```text
r(A/B) = s(A) - s(B)
```

`s(A)` und `s(B)` sind Währungs-Node-Returns relativ zu einer fest gewählten Gauge, zum Beispiel mit der Nebenbedingung `sum(s)=0`. Für alle Paare zusammen:

```text
r_pair = B · s
```

`B` ist die Inzidenzmatrix des Währungsgraphen. Bei `N` verbundenen Währungen hat `B` Rang `N-1`. Für FX8 sind deshalb höchstens sieben Währungsrichtungen unabhängig, auch wenn 28 direkte Crosses vorliegen.

Für Paargewichte `w` ergibt sich das Netto-Währungsexposure als:

```text
e_currency = Bᵀ · w,       sum(e_currency) = 0
```

Das ist mehr als eine mathematische Eleganz:

- `long EURUSD`, `long GBPUSD` und `long AUDUSD` sind drei Tickets, aber zugleich eine konzentrierte Short-USD-Wette.
- Zwei Spreads mit gemeinsamen Legs können dasselbe Währungsrisiko doppelt enthalten.
- Long/Short-Ausgewogenheit auf Ticketebene garantiert keine Währungsneutralität.
- Pair-Korrelationen allein reichen für Limits und Attribution nicht aus.

Executable Bid/Ask-Returns weichen wegen Spread, asynchronen Quotes, Swap und Kontowährungsumrechnung von der idealen Graphidentität ab. Gerade diese Abweichungen sind Kosten bzw. Datenqualität – nicht automatisch Alpha.

### 1.2 Fünf verschiedene Architekturen

| Architektur | Gemeinsame Abhängigkeit | Sinnvolle V5-Repräsentation | Beurteilung |
|---|---|---|---|
| Multi-Symbol-Signal, Single-Leg-Ausführung | Viele Paare liefern einen Rank/Regime-Score; nur ein Cross wird gehandelt | ein logischer Basket, ein ausgeführtes Symbol | beste erste Passform; geringe Kosten und kein Cross-Leg-Atomicity-Risiko |
| Selector Basket | Währungs-Nodes werden gemeinsam gerankt; ein oder zwei direkte Crosses bilden die Extreme ab | ein logisches Basket-Instrument | guter Fit bei langsamem Rebalance und klaren Currency-Caps |
| Atomisches Relative-Value-Paket | Entry, Exit und Hedge sind nur gemeinsam sinnvoll | ein Basket mit Package-State | hohe Ausführungs- und Recovery-Anforderungen |
| Gemeinsamer Multi-Sleeve-Allocator | mehrere nicht atomische Trend-/Value-Legs teilen Vol-Target und Exposure-Limits | ein Basket nur, wenn Joint Sizing zwingend ist | sonst unabhängige Sleeves für Fehlerisolation bevorzugen |
| Externes Portfolio unabhängiger EAs | keine gemeinsame Signal- oder Exitlogik | Q12-Portfolio, nicht „Multicurrency-Alpha-EA“ | Legs dürfen nicht als interne Diversifikatoren doppelt gezählt werden |

**Architekturregel:** Nur dann in einen gemeinsamen EA zwingen, wenn Signal, Exposure, Sizing oder Package-Exit tatsächlich gemeinsam sein müssen. Eine bloße Liste mehrerer FX-EAs ist ein Portfolio, keine neue Strategieklasse.

## 2. Strategieklassen

### 2.1 Cross-sectional Currency Momentum

**Mechanismus.** Währungen zu einem festen Stichtag nach ihrem vergangenen Return relativ zum Währungskorb ranken; starke Währungen long, schwache short. Die Ausführung erfolgt idealerweise direkt als stärkstes gegen schwächstes Cross, statt dieselbe Wette über zwei USD-Legs synthetisch aufzubauen.

**Evidenz.** Menkhoff et al. dokumentieren Currency Momentum für Formation/Haltedauer-Kombinationen von 1 bis 12 Monaten; der Faktor ist von Carry verschieden, ein Teil der Bruttorendite wird jedoch durch Transaktionskosten aufgezehrt. [BIS Working Paper 366](https://www.bis.org/publ/work366.htm)

**V5-Fit.** Hoch, wenn D1/monatlich, mit festem Universum, wenigen Rebalances und Currency-Caps. Niedrig bei wöchentlichen Filterketten oder vielen knapp wechselnden Rangpositionen.

**Hauptgefahren.** Kleines G8-Universum, Rank-Churn, Konzentration auf eine Währung, Quote-Inversionsfehler, Kosten an den Ranggrenzen und nachträglich gewählte Formation-/Filterkombinationen.

### 2.2 Time-series Momentum / Trend

**Mechanismus.** Jede vordefinierte Währungsrichtung wird anhand ihres eigenen vergangenen Returns long oder short; das gemeinsame Portfolio wird meist invers volatilitätsgewichtet. In einem basiswährungsneutralen Node-Modell bedeutet „eigener Return“ immer „relativ zur fest definierten Korb-Gauge“ und muss genau so benannt werden.

**Evidenz.** Die klassische Studie von Moskowitz, Ooi und Pedersen findet 1–12-monatige Fortsetzung in 58 Futures-/Forward-Märkten einschließlich Währungen; die verbreitete Spezifikation nutzt zwölf Monate Formation, monatliche Aktualisierung und inverse Volatilität. Die Evidenz ist cross-asset und daher nicht automatisch ein Beweis für ein kleines FX8-Spot-Universum. [Time Series Momentum](https://www.aqr.com/insights/research/journal-article/time-series-momentum)

**V5-Fit.** Mittel bis hoch. Niedriger Turnover und nicht-atomische Legs helfen operativ. Doppelte USD-Exposures, Volatilitätshebel und Trend-Reversals nach Krisen müssen jedoch auf Basketebene geprüft werden.

### 2.3 Carry

**Mechanismus.** Hochverzinsliche bzw. positiv rollende Währungen long, niedrigverzinsliche/negativ rollende short. Akademisch wird Carry typischerweise über Forward-Discounts oder Zinsdifferenzen definiert; im DarwinexZero-Rolling-Spot muss die operative Größe die tatsächlich erwartete Netto-Swap-Rendite sein.

**Evidenz.** Carry ist eine dokumentierte globale Risikoprämie, aber mit Verlusten in Phasen unerwartet steigender globaler FX-Volatilität. [Menkhoff et al., Global FX Volatility and Carry Trades](https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1540-6261.2012.01728.x) Darwinex erläutert zugleich, dass Long- und Short-Swaps asymmetrisch, LP-markiert und veränderlich sind. [Darwinex Execution Costs](https://help.darwinex.com/execution-costs)

**V5-Fit.** Ökonomisch gut, gegenwärtig datenblockiert. `.DWX`-Backtests buchen im vorhandenen Setup keinen belastbaren historischen Swapstrom; ein statischer, veröffentlichter Point-in-time-Swapkatalog liegt nicht vor. Ein Test, der aktuelle `SYMBOL_SWAP_LONG/SHORT` rückwirkend als Signal liest, enthält keine historische Carry-Zeitreihe.

**Zulässige spätere Variante.** Monatlicher Net-Swap-Rank mit einfacher, verzögerter globaler FX-Volatilitätsskalierung. Keine binäre, nachträglich optimierte Regimeampel; fehlende Historie muss fail-closed sein.

### 2.4 Value / PPP / REER

**Mechanismus.** Relativ unterbewertete Währungen long und überbewertete short, beispielsweise anhand langsamer realer Wechselkursänderungen oder eines fundamental bereinigten Value-Scores.

**Evidenz.** Currency Value ist von Momentum und Carry unterscheidbar; die Literatur verwendet reale Wechselkurse und teils Produktivität, Exportqualität, Nettoauslandsvermögen und Output Gap. [Currency Value, Review of Financial Studies](https://openaccess.city.ac.uk/id/eprint/14851/) Value und Momentum zeigen auch über Assetklassen komplementäre Eigenschaften. [Value and Momentum Everywhere](https://www.aqr.com/insights/research/journal-article/value-and-momentum-everywhere)

**V5-Fit.** Als langsamer Diversifikator attraktiv, aber nicht ohne Veröffentlichungszeitpunkt und Revisionshistorie. Ein heutiger, revidierter REER-/CPI-Wert darf nicht in frühere Entscheidungszeitpunkte zurückgeschrieben werden. Niedrige Tradezahl kann zudem mit der aktuellen Frequenzregel kollidieren.

### 2.5 Relative Value / Cointegration / Spreads

**Mechanismus.** Ein wirtschaftlich begründeter Paar- oder Korbspread wird um ein fest oder rollierend geschätztes Gleichgewicht gehandelt.

**FX-spezifisches Problem.** Viele scheinbare Beziehungen sind Identitäten oder Numeraire-Effekte. Beispielsweise ist `log(EURUSD) - log(GBPUSD) = log(EURGBP)`. Ein stabiler Residualspread kann daher bloß ein synthetischer Cross sein; negative Betas können sogar gleichgerichtete, nicht neutrale Legs erzeugen.

**V5-Fit.** Nur für einen ex ante begründeten Einzelfall, mit gemeinsamer Zeitbasis, fixierter DEV-Schätzung, Strukturbruch-/Half-Life-Regeln und echter Multi-Leg-Kostenrechnung. Nicht geeignet für eine neue Suche über alle Paare, Betas, Fenster und Filter.

### 2.6 Defensive / Low-Vol / Safe-Haven

**Mechanismus.** Vol-Targeting und Currency-Caps sind sinnvolle Risiko-Overlays. Eine eigenständige statische „CHF/JPY long in risk-off“-Alpha-These ist schwächer: Safe-Haven-Rollen ändern sich nach Schocktyp und Regime. Die EZB dokumentiert etwa, dass der EUR in mehreren Risk-off-Phasen 2025/Anfang 2026 zusammen mit traditionellen Safe-Haven-Währungen aufwertete. [EZB, International Role of the Euro 2026](https://www.ecb.europa.eu/press/other-publications/ire/html/ecb.ire202606.en.html)

**V5-Fit.** Als vorab definierter Q08-Krisen- oder Sizing-Overlay prüfen, nicht als erste Standalone-Card. Volatilität muss gelaggt sein und Floor/Cap besitzen; sonst drohen prozyklisches Deleveraging und hoher Leverage auf scheinbar ruhige Pegs. [Volatility-Managed Portfolios](https://www.nber.org/papers/w22208)

### 2.7 Kurzfristige Reversion, Lead/Lag und Dreiecksarbitrage

**Urteil.** Für die aktuelle V5-/DarwinexZero-Umgebung nicht weiterverfolgen.

- Interne H1-Lead/Lag-Signale wechselten OOS das Vorzeichen.
- Kurzfristige cross-sectional USD-Reversion zeigte Bruttoeffekte, war nach Kosten auf H1/D1 negativ.
- Dreiecksarbitrage zahlt drei Spreads/Kommissionen, benötigt synchrone executable Quotes und praktisch atomare Ausführung. Publizierte Hochfrequenzchancen sind meist sehr klein und kurzlebig; ein MT5-Testergewinn wäre besonders anfällig für Feed-Asynchronität. [Norges Bank, Arbitrage in the FX Market](https://www.norges-bank.no/en/news-events/publications/Working-Papers/2005/200512/)

### 2.8 „Currency Strength“ und Regimefilter

Ein aus Paarreturns geschätzter Currency-Strength-Score ist eine **Darstellung**. Wenn er vergangene Returns rankt, ist er Momentum; wenn er Swaps rankt, Carry; wenn er REER rankt, Value. Ohne separaten Mechanismus ist „Currency Strength“ kein neuer Return-Treiber.

Regimefilter sind ebenfalls keine Alpha-Klasse. Sie sind nur zulässig, wenn Variable, Lag, Schwelle, Verhalten bei fehlenden Daten und Falsifikation vorab feststehen. Ein Filter, der fehlende Historie als „grün“ behandelt, ist für Evidenzzwecke unzulässig.

## 3. Interner Bestand und gelernte Evidenz

### 3.1 Deduplizierung ist das erste Gate

Ein read-only Filesystem-Snapshot am 2026-07-15 ergab 203 `basket_manifest.json`, darunter 53 FX-only-Manifeste. Innerhalb dieser 53 befinden sich 25 Zwei-Symbol-, acht Drei-Symbol-, 13 Vier-Symbol- und vier vollständige 28-Pair-FX8-Manifeste. Namen/Metadaten enthalten bereits zahlreiche Cointegration-, Carry-, Cross-sectional-, Basket- und Currency-Strength-Familien. Die Zählung ist Inventar, kein Qualitäts- oder Statusurteil.

Vier vollständige FX8/28-Pair-Lineages existieren bereits:

- `QM5_10717` – cross-sectional FX momentum;
- `QM5_10718` – regime-filtered carry;
- `QM5_11012` – strength-pair;
- `QM5_12821` – TWIN currency-strength basket.

Damit ist „noch ein FX8-Ranker“ ohne Lineage-Abgleich keine neue These.

### 3.2 Relevante Lineages

| Lineage | Vorhandene Idee/Evidenz | Survey-Urteil |
|---|---|---|
| `QM5_10717` | FX8/28-Pair, wöchentlicher 63D-Strength-Rank, Top/Bottom-Paare, Vol-Filter | wichtigste Momentum-Referenz; Architektur-/Setfile-Lineage vor neuem Benchmark klären |
| `QM5_1111` | monatliches 12M-FX-Momentum auf sieben USD-Crosses | nahe Literaturvariante; gemeinsam mit 10717 deduplizieren |
| `QM5_12614` | 6M-TSMOM auf drei FX-Paaren, monatlich/inverse Vol | TSMOM-Referenz; Card/EA/Manifest-Lineage ist nicht vollständig konsistent |
| `QM5_10718` | FX8 Carry aus Broker-Swapfeldern plus Regimefilter | historische Signalevidenz blockiert: aktuelle Properties, `.DWX`-Swaplücke und fail-open Filter |
| `QM5_1127` | „Carry“ teilweise über Price Momentum bzw. aktuelle Rates approximiert | nicht als Carry akzeptieren; Mechanismus falsch substituiert |
| `QM5_1092` | PPP/Value mit externem CPI-/PPP-Input | sinnvolle primitive Idee, aber point-in-time Makrodaten fehlen |
| `QM5_12532` | AUDUSD/NZDUSD Cointegration | Q02/Q04 zunächst positiv, Q05 PF 0,95 / FAIL |
| `QM5_12533` | EURJPY/GBPJPY Cointegration | Q02 positiv, Q04 pooled PF 0,432 / FAIL |
| `QM5_13117` | sign-aware EURGBP/AUDJPY, negative Beta, Q02–Q07 früh positiv | frischer Annual-Density-/Recency-Reject; `RESEARCH_ONLY_NO_GO` |

Die interne Discovery-Evidenz ist eindeutig:

- Der 66-Pair-Scan brachte nur zwei positive-beta Survivors hervor; beide wurden weiterverfolgt und scheiterten später.
- Die sieben qualifizierenden sign-aware Cointegration-Rows sind bereits als Cards/EAs repräsentiert.
- Das zur Auswahl verwendete Fenster ist nach der Auswahl kein unberührtes OOS mehr.
- TWIN Currency-Strength Continuation war breit negativ; ein Fade-Effekt war auf ein einzelnes 2024-Regime konzentriert.

Siehe [Cross-Asset/FX Discovery](CROSS_ASSET_FX_DISCOVERY_2026-06-09.md), [TWIN Final Dossier](TWIN_FINAL_DOSSIER_2026-07-02.md) und den [frischen 13117 Annual-Density-Reject](../../artifacts/ftmo_13117_eurgbp_audjpy_fresh_annual_density_gate_failure_2026-07-12.json).

### 3.3 Kosten- und Swaprealität

Die vorhandene Kommissionsstrecke kann realistische instrumentenspezifische Prozent-vom-Notional-Kosten abbilden. Für längere FX-Haltedauern bleibt Swap ein separater, materieller Cashflow. Nach der internen Swap-Recherche gibt es derzeit keine belastbare statische historische DarwinexZero-Swapreihe; Triple-Day, Long/Short-Asymmetrie und zeitliche Änderungen müssen datiert werden. Siehe [Swap Research](SWAP_RESEARCH_FTMO_DXZ_5PERS_2026-06-09.md), [DL-073](../../decisions/DL-073_q04_realistic_notional_commission.md) und [DL-072 Cost Cushion](../../decisions/DL-072_q08_cost_cushion_gate.md).

## 4. Priorisierte Kandidaten

Alle folgenden Bezeichnungen sind Survey-Labels, **keine EA-IDs und keine Strategy Cards**.

### P0 — `MC-R0 Lineage Reconciliation`

**Status:** notwendige Research-Vorarbeit, keine Strategie.

Vor jeder G0/Q00-Einreichung sind `10717`, `1111`, `12614`, `11012` und `12821` auf folgende Punkte abzugleichen:

- kanonische Quelle und exakter Return-Treiber;
- Universum, Orientierung und Node-Schätzung;
- Formation, Skip, Rebalance und Halteperiode;
- Zahl der gleichzeitig gehandelten Crosses;
- Filter und Risikoskalierung;
- logical-basket Manifest/Setfile versus alter Per-Pair-Fan-out;
- bereits konsumierte DEV-/Selection-/OOS-Zeiträume;
- aktueller Funnelstatus und frühere Kill-Evidenz.

Ergebnis soll ein Lineage-Dossier sein: eine kanonische Baseline, wenige vorab deklarierte Falsifikationen und eine Liste echter Duplikate. Die neuere G0-Regel verlangt für eine spätere Card genau einen kanonischen `source_id`; dieses Memo darf und soll dagegen mehrere Survey-Quellen enthalten.

### P1 — `MC-01 FX8 XSMOM 6/1 Node Benchmark`

**Status:** `PROPOSED_FOR_G0_REVIEW AFTER DEDUP`  
**Nächste Lineages:** `QM5_10717`, `QM5_1111`  
**Return-Treiber:** langsame cross-sectional Return-Fortsetzung

**Präregistrierbarer Benchmark:**

- festes, registry-clean FX8-Universum; keine automatische Erweiterung auf alle aktuell beim Broker angebotenen Paare;
- monatlicher Entscheidungszeitpunkt auf vollständig geschlossenen, gemeinsamen D1-Bars;
- sechs Monate Formation, ein Monat Haltedauer;
- Währungs-Scores in kanonischer Orientierung und mit `sum(score)=0`;
- Baseline: stärkster gegen schwächsten Node als ein direktes Cross;
- einzige Construction-Falsifikation: Top-2 gegen Bottom-2 als zwei disjunkte direkte Crosses;
- feste Equal-Risk- oder lagged-inverse-vol Regel, nicht beides nach Ergebnis auswählen;
- Caps auf Einzelwährung, Gross, USD und tatsächliches Exposure nach Fills;
- kein zusätzlicher Vol-/Regimefilter in der Baseline.

**Warum zuerst:** starke direkte FX-Literatur, niedrige Datenhürde, geringe Frequenz und in der Single-Leg-Variante minimale Package-Komplexität.

**Kill-Kriterien:**

- Ergebnis hängt nur an einer Währung, einem Jahr oder einem Mapping;
- Vorzeichen/Qualität zerfällt zwischen FX28-Graph und vordefiniertem Sieben-Paar-Spanning-Tree;
- Cost Cushion unter dem V5-Mindestniveau;
- Rang-Churn trägt mehr Kosten als Gross Edge;
- nur eine nachträglich gewählte Filtervariante überlebt;
- kein unberührter Holdout nach Berücksichtigung der bestehenden Lineages.

### P2 — `MC-02 FX Trend 12/1 Basket`

**Status:** `PROPOSED_FOR_G0_REVIEW AFTER DEDUP`  
**Nächste Lineage:** `QM5_12614`  
**Return-Treiber:** langsame eigene Return-Fortsetzung

**Präregistrierbarer Benchmark:**

- zwölf Monate Formation, monatlicher Rebalance;
- ein festes, vorab benanntes Set unabhängiger Währungsrichtungen;
- Long bei positivem, short bei negativem 12M-Return relativ zur ausdrücklich definierten Gauge;
- lagged inverse Volatilität mit Floor, Cap und Basket-Vol-Ziel;
- harte Currency-/USD-Exposure-Caps;
- keine atomische Paketannahme: jedes Leg ist ökonomisch eigenständig, aber gemeinsame Sizing- und Exposure-Entscheidungen müssen reproduzierbar sein.

**Offene Architekturfrage:** Wenn gemeinsames Vol-Target und Currency-Caps exakt in Q12 reproduzierbar sind, können unabhängige Sleeves bessere Fehlerisolation bieten. Nur wenn das Joint Sizing Teil der Strategie ist, ist ein gemeinsamer Basket-EA gerechtfertigt.

**Kill-Kriterien:** Ergebnis ausschließlich aus USD-Beta, unvertretbare Trend-Reversal-Verluste in Q08, Leverage aus niedriger geschätzter Volatilität, fehlende Robustheit bei fixem 6M-Komparator oder fehlender Mehrwert gegenüber vorhandenen Trend-Sleeves.

### P3 — `MC-03 FX8 Value–Momentum Composite`

**Status:** `DATA-FIRST RESEARCH; NOT READY FOR CARD`  
**Nächste Lineages:** `QM5_1092` plus kanonische Momentum-Lineage  
**Return-Treiber:** langsame fundamentale Konvergenz plus komplementäre Preisfortsetzung

**Hypothese:** Ein einfaches, festes 50/50-Composite aus einem point-in-time 5Y-REER/PPP-Value-Z-Score und einem kanonischen 6M- oder 12M-Momentum-Z-Score könnte stabiler sein als eine der Komponenten allein.

**Reihenfolge:** Zuerst beide Primitives separat mit derselben Zeitbasis validieren. Erst danach das Composite als genau eine vorab festgelegte Kombination prüfen. Kein Gewichts-, Schwellen- oder Regime-Mining.

**Blocker/Kill:** keine Point-in-time Vintages, zu wenige echte Portfolioänderungen für die Frequenzregel, Ergebnis nur aus revidierten Makrodaten oder kein marginaler Q12-Diversifikationsbeitrag.

### P4 — `MC-04 Net-Swap Carry + Lagged FX Vol`

**Status:** `HARD DATA BLOCKED`  
**Nächste Lineage:** `QM5_10718`  
**Return-Treiber:** Carry-Risikoprämie, reduziert bei ex ante hoher globaler FX-Volatilität

**Mindestdaten vor einer Card:**

- datierte Long-/Short-Swaps je Symbol und Swap-Modus;
- Punkte-zu-Kontowährung-Konversion zum damaligen Zeitpunkt;
- Triple-Rollover-/Holiday-Regeln;
- alternativ ein sauberer point-in-time Forward-Discount-Datensatz, wobei die Abweichung zum live handelbaren Broker-Swap separat modelliert wird;
- fehlende Daten führen zu `INVALID/NO_TRADE`, nicht zu einem grünen Regime.

**Nicht zulässig:** aktuelle Swaps rückwärts applizieren, aktuelle Zentralbankzinsen als historische vollständige Carryserie verwenden oder Price Momentum „Carry“ nennen.

### P5 — `MC-05 Dynamic Safe-Haven Rotation`

**Status:** `OVERLAY / CRISIS COMPARATOR ONLY`.

Kein statischer CHF-/JPY-/USD-Roster als erste Alpha-Card. Zulässig wäre später eine kleine, mechanische und gelaggte Krisen-Falsifikation für P1/P2/P4. Sie muss ausdrücklich zeigen, ob sie Gross Edge hinzufügt oder nur Drawdown zeitlich verschiebt.

### P6 — bestehende sign-aware Cointegration

**Status:** `HOLD EXISTING EVIDENCE; NO NEW SCAN`.

`QM5_13117` bleibt ein informativer Grenzfall, aber kein aktueller Weiterlaufkandidat: negative Beta erzeugt richtungsähnliche Legs; die frische Evidenz zeigt Nulltrade-Jahre 2017 und 2025. Die übrigen qualifizierten Rows sind bereits gebaut und an Q04/Q05 gescheitert. Eine neue Pair-Suche würde denselben Hypothesenraum erneut minen.

## 5. V5-Vertrag für Multicurrency-Evidenz

### 5.1 Ein Basket, ein Work Item, eine Equity

Der spezifische [Cross-Sectional Basket Pipeline Design Contract](../ops/CROSS_SECTIONAL_BASKET_PIPELINE_DESIGN_2026-05-22.md) legt fest:

- genau ein logisches Basket-Instrument;
- genau ein Host-Chart als Runner-Anker;
- vollständige Fremdsymbol-/Datenabhängigkeiten im `basket_manifest.json`;
- kombinierte Basket-PnL und Equity als Gate-Gegenstand;
- Leg-, Long/Short-, Kosten- und Currency-Exposure-Attribution als Diagnostik;
- kein isolierter Per-Pair-Fan-out und keine Mehrfachinstanzen desselben Baskets.

Das ist die fachlich richtige Einheit. Ein älterer [Backtest Execution Discipline Process](../../processes/16-backtest-execution-discipline.md) verlangt noch 36 Symboltests, während der neuere [Pipeline Phase Spec](../ops/PIPELINE_PHASE_SPEC.md) für Baskets ausdrücklich das logical work item verwendet. **Empfehlung an OWNER:** die spezifische Basket-Ausnahme als Vorrang ratifizieren und die Prozessdrift separat bereinigen. Dieses Memo ändert keine Governance.

### 5.2 Frequenz ohne Leg-Inflation

Die aktuelle OWNER-Regel nennt mindestens fünf Trades pro Jahr und Symbol. Bei einem rotierenden Selector Basket kann ein einzelnes Symbol korrekt selten gewählt werden, obwohl der Basket monatlich entscheidet. Umgekehrt kann ein Zwei-Leg-Paket dieselbe ökonomische Entscheidung künstlich als zwei Trades zählen.

**Vorgeschlagene, noch zu ratifizierende Messung:**

- Primär: echte logische Basket-Zyklen bzw. Rebalances mit Positionsänderung pro Jahr;
- Sekundär: Deals, Packages und Aktivität je Symbol vollständig ausweisen;
- keine Leg-Deals zur Frequenzaufblähung;
- weiterhin Jahreslücken und lange no-trade-Regime als eigene Recency-/Density-Fails behandeln.

### 5.3 Gemeinsame Entscheidungszeit

Ein Host-Tick ist keine Basket-Zeit. MT5 weist darauf hin, dass Bars anderer Symbole im Tester asynchron verfügbar werden können. [Offizielle MQL5 Multicurrency-Testdokumentation](https://www.mql5.com/en/book/automation/tester/tester_multicurrency_sync)

Nicht verhandelbar:

- ein expliziter `decision_timestamp`;
- nur vollständig geschlossene Bars;
- exakt gleicher As-of-Zeitpunkt über alle Signal- und Trade-Symbole;
- Zeitstempelabgleich, nicht bloß Arrays nach Shift zusammenzippen;
- gemeinsamer History-Intersection und Mindestbarzahl;
- stale/fehlende Daten führen fail-closed zu `INVALID/NO_TRADE`;
- Cold- und Warm-Cache-Replay müssen denselben Signalplan ergeben.

Der Repo-Fall mit Ticks bis 2025, aber D1-Cache nur bis 2024 zeigt, dass „History geladen“ ohne gemeinsame Endzeit kein ausreichendes Gate ist.

### 5.4 Traded, Signal-only und Conversion Symbols

Das Manifest muss mindestens unterscheiden:

- tatsächlich gehandelte Legs;
- reine Signal-/Warmup-Symbole;
- Kontowährungs-/Margin-Conversion-Symbole;
- Host-Anker;
- gemeinsame benötigte Historie und Timeframe.

Die vollständige Liste aller gelesenen Symbole darf nicht mit den tatsächlich risk-bearing Legs verwechselt werden.

### 5.5 Kosten und Cashflows

Für jedes Leg und aggregiert:

- executable spread;
- realistische Commission;
- Slippage und Reihenfolgeeffekt;
- Long-/Short-Swap inklusive Triple-Day;
- Kontowährungsumrechnung;
- Rebalance-Turnover;
- Kosten eines fehlgeschlagenen Opens plus Rollback;
- Margin des Gesamtplans, nicht nur jedes Legs isoliert.

DL-072 verlangt für einen robusten PASS `cost_cushion >= 2`; `1–2` ist soft und `<1` hard fail. Bei einem Basket ist der Nenner die realistische Summe aller Leg- und Recovery-Kosten.

### 5.6 Multi-Leg-Ausführung ist nicht atomar

MT5/DarwinexZero bietet keine transaktionale, atomare Mehrbein-Order. Für echte Packages muss die spätere Spezifikation daher mindestens enthalten:

```text
IDLE → PLANNED → PRECHECKED → OPENING → OPEN
                           ↘ RECOVERING → FLAT
```

Erforderlich wären eine idempotente `rebalance_id`, Soll-/Ist-Volumen je Leg, Gesamtmargin-Precheck, Partial-Fill-Reconciliation, maximale Leg-Skew, deterministischer Rollback, Orphan-Cleanup und Restart-Recovery. Während `RECOVERING` darf kein neues Signal ausgeführt werden.

Dies ist ein Research-/Design-Kriterium, kein Implementierungsauftrag. Es spricht klar für die Single-Leg-Ausführung von P1 als ersten Kandidaten und gegen Dreiecksarbitrage.

### 5.7 Exposures und Account-Vertrag

- Soll- und Ist-Exposure nach jedem Deal auf Währungs-Nodes aggregieren.
- Limits für Einzelwährung, USD/Account Currency, Gross, Long/Short-Imbalance und Teilfillzustand.
- Direkte Crosses bevorzugen, wenn sie dieselbe Node-Wette mit weniger Legs und niedrigeren Kosten abbilden.
- Hedging-Accountmodus, Fill-Mode, Trade-Mode, FIFO-Regel und Symbol-Mapping später hard-gaten.
- Interne Basket-Legs in Q12 nicht als unabhängige Sleeves oder Diversifikatoren zählen.

### 5.8 Gate-spezifische Mindesttests Q00–Q13

| Gate-Bereich | Multicurrency-Ergänzung |
|---|---|
| Q00 | kanonische Quelle, Return-Treiber, immutable Universum/Manifest, Entscheidungsuhr, point-in-time Daten, Trial-Ledger, Failure-/Rollback-Hypothese |
| Q01 | Compile/Contract, Cold-/Warm-Cache-Replay, identischer Signalplan-Hash, fehlende Daten fail-closed, Host-Anker darf Signal nicht ändern |
| Q02 | genau ein logical work item; Basket-PnL netto aller Legs/Kosten; Frequency-Unit vorab ratifiziert |
| Q03 | nur präregistrierte Strukturvarianten; kein Pair-, Universe-, Filter- oder Lookback-Mining |
| Q04 | Zeit- und Construction-Robustheit; Spanning-Tree vs. Full Graph, Long/Short-Seiten, Currency- und Leg-Attribution |
| Q05 | Walk-forward mit Embargo; bereits zur Selektion verwendete Fenster sind DEV/Selection, nicht erneut OOS |
| Q06–Q07 | gemeinsame Spread-/Swap-/Slippage-Schocks; bei Packages Reject, Partial Fill, Leg-Reihenfolge, Rollback und Restart |
| Q08 | Basket-Equity plus Leg-/Currency-Attribution; Momentum-Reversal, Carry-Crash und relevante historische Krisenslices |
| Q09 | Seed darf nicht vom Aufrufspfad abhängen; Schocks deterministisch aus Seed, Timestamp, Symbol, Leg und Event ableiten |
| Q10 | DSR/PBO/FDR/MC auf Basketreturns und die vollständige Hypothesenfamilie, nicht nur den überlebenden Parametersatz |
| Q11 | News-Blackout als Vereinigung aller tatsächlich exponierten Währungen/Symbole; kein einzelnes Host-Symbol als Proxy |
| Q12 | ein Basket = ein Sleeve; marginale Buchdiversifikation, Currency-/Gross-Caps und keine Doppelzählung interner Legs |
| Q13 | genau eine Host-Instanz; native Symbolauflösung, Hedging-/Margin-/Partial-Fill-/Rollback-/Restart-Readiness |

Q14/T_Live ist ausdrücklich außerhalb dieses Auftrags.

## 6. Pre-G0-Screening

### Hard Veto

Kein Kandidat soll gecardet werden, wenn einer dieser Punkte offen bleibt:

- kein exaktes DarwinexZero-Live-Symbolmapping;
- keine gemeinsame point-in-time Historie;
- undefinierte Entscheidungsuhr;
- heutige Broker-/Makro-Properties werden rückwirkend als historisches Signal verwendet;
- kein vollständiges Trial-Ledger oder kein unberührter Holdout;
- nicht reproduzierbarer Signalplan;
- bei echtem Package keine Partial-Fill-/Rollback-/Restart-Policy;
- Currency Exposure und Gesamtmargin sind nicht berechenbar.

### Bewertungsrubrik nach bestandenem Hard Veto

| Dimension | Gewicht |
|---|---:|
| ökonomischer Mechanismus und klare Falsifikation | 15 |
| Live-Symbol- und point-in-time Datenqualität | 15 |
| kausale Synchronisierung und Replay-Determinismus | 15 |
| Kosten-/Swap-/Turnover-Cushion | 15 |
| Ausführungs-, Margin-, Partial-Fill- und Restart-Sicherheit | 15 |
| wenige Freiheitsgrade und ehrliche Trial-Zahl | 10 |
| marginale Diversifikation und kontrollierte Currency Exposure | 10 |
| Pipeline-/Betriebskomplexität | 5 |

Ein Score wäre vor Daten-/Lineage-Reconciliation Scheingenauigkeit. Als qualitative Vorstufe ergibt sich:

| Kandidat | Mechanismus | Datenreife | Ausführungsfit | Novelty nach Dedup | Vorläufiges Urteil |
|---|---|---|---|---|---|
| P1 XSMOM 6/1 | stark | hoch | hoch, besonders Single-Leg | mittel | erste G0-Prüfung nach Dedup |
| P2 TSMOM 12/1 | stark, aber breitere cross-asset Evidenz | hoch | mittel/hoch | mittel | zweite G0-Prüfung nach Dedup |
| P3 Value–Momentum | stark/komplementär | niedrig | hoch | mittel | point-in-time Datenprojekt |
| P4 Carry + FX Vol | stark | unzureichend | mittel | gering/mittel | hard blocked |
| P5 Safe-Haven | wechselnd | mittel | hoch | mittel | nur Overlay/Q08 |
| P6 Cointegration | fallspezifisch | mittel | niedrig bei Packages | sehr gering | keine neue Suche |

## 7. Empfohlene Reihenfolge

1. **Keine neue EA-ID und keine neue Strategy Card anlegen.**
2. `MC-R0` als reines Lineage-/Evidence-Dossier für 10717/1111/12614/11012/12821 erstellen.
3. OWNER/QB ratifiziert vor jedem Lauf:
   - logical Basket statt Per-Symbol-Fan-out;
   - Frequency-Unit für rotierende Baskets;
   - welches bereits verwendete Zeitfenster Selection/DEV ist;
   - eine kanonische Quelle und höchstens die genannten Construction-Falsifikationen.
4. Danach zuerst P1 XSMOM, anschließend P2 TSMOM als mechanische Benchmarks zur G0/Q00-Prüfung vorlegen.
5. Parallel nur Daten-Reconnaissance für historische Swaps/Forward-Discounts und point-in-time REER/CPI-Vintages; ohne diese keine Carry-/Value-Card.
6. P3 erst nach separat bestandenen Primitives; P4 erst nach geschlossenem Swap-Gate.
7. Keine neue Cointegration-, Short-Horizon-Reversion-, Lead/Lag- oder Triangle-Familie öffnen.

## 8. OWNER-Entscheidungspunkte

1. Soll der spezifische logical-basket Vertrag formell Vorrang vor dem älteren 36-Symbol-Fan-out erhalten?
2. Wird bei Selector Baskets die Mindestfrequenz primär auf echte Basket-Zyklen/Rebalances angewandt, bei zusätzlicher vollständiger Symbolaktivitäts-Evidenz?
3. Welche bestehende Lineage wird kanonischer Momentum-Anker: 10717, 1111 oder ein reconciliertes gemeinsames Dossier?
4. Soll als erste Quelle/Familie XSMOM 6/1 oder TSMOM 12/1 in G0/Q00 gehen? Empfehlung: XSMOM zuerst.
5. Ist ein separates point-in-time Datenprogramm für Swap/Forward-Discount und REER/CPI-Vintages gewünscht? Ohne OWNER-Freigabe bleibt es Research-Backlog.

## 9. Quellen

### Interne Primärreferenzen

- [V5 Source of Truth und Hard Rules](../../CLAUDE.md)
- [Operating Rules 2026-07-03](../ops/OPERATING_RULES_2026-07-03.md)
- [Pipeline Phase ID Map](../ops/PIPELINE_PHASE_ID_MAP.md)
- [Pipeline Phase Spec](../ops/PIPELINE_PHASE_SPEC.md)
- [Cross-Sectional Basket Pipeline Design](../ops/CROSS_SECTIONAL_BASKET_PIPELINE_DESIGN_2026-05-22.md)
- [Cross-Asset/FX Discovery](CROSS_ASSET_FX_DISCOVERY_2026-06-09.md)
- [FX Swap Research](SWAP_RESEARCH_FTMO_DXZ_5PERS_2026-06-09.md)
- [Edge Theses: Cross-Sectional](EDGE_THESES_CROSS_SECTIONAL_2026-05-22.md)
- [Edge Quality Research Synthesis](EDGE_QUALITY_RESEARCH_SYNTHESIS_2026-06-09.md)
- [TWIN Final Dossier](TWIN_FINAL_DOSSIER_2026-07-02.md)
- [DL-064 Portfolio Construction Layer](../../decisions/DL-064_portfolio_construction_layer.md)
- [DL-072 Cost Cushion Gate](../../decisions/DL-072_q08_cost_cushion_gate.md)
- [DL-073 Realistic Notional Commission](../../decisions/DL-073_q04_realistic_notional_commission.md)

### Externe Primär-/offizielle Quellen

- Menkhoff et al., [Currency Momentum Strategies](https://www.bis.org/publ/work366.htm)
- Moskowitz, Ooi, Pedersen, [Time Series Momentum](https://www.aqr.com/insights/research/journal-article/time-series-momentum)
- Menkhoff et al., [Currency Value](https://openaccess.city.ac.uk/id/eprint/14851/)
- Asness, Moskowitz, Pedersen, [Value and Momentum Everywhere](https://www.aqr.com/insights/research/journal-article/value-and-momentum-everywhere)
- Menkhoff et al., [Global Foreign Exchange Volatility and the Carry Trade](https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1540-6261.2012.01728.x)
- Brunnermeier, Nagel, Pedersen, [Carry Trades and Currency Crashes](https://www.nber.org/papers/w14473)
- Moreira, Muir, [Volatility-Managed Portfolios](https://www.nber.org/papers/w22208)
- Norges Bank, [Arbitrage in the Foreign Exchange Market](https://www.norges-bank.no/en/news-events/publications/Working-Papers/2005/200512/)
- MQL5, [Multicurrency Testing and Synchronization](https://www.mql5.com/en/book/automation/tester/tester_multicurrency_sync)
- Darwinex, [Assets Available](https://help.darwinex.com/assets-available)
- Darwinex, [Execution Costs](https://help.darwinex.com/execution-costs)
- ECB, [The International Role of the Euro, June 2026](https://www.ecb.europa.eu/press/other-publications/ire/html/ecb.ire202606.en.html)

---

## Scope Attestation

Für diesen Auftrag wurden ausschließlich Research, read-only Bestands-/Governance-Abgleich und dieses Memo erstellt. Es wurden keine EA-/Framework-/Registry-Dateien geändert, keine Builds oder Pipelinephasen ausgeführt, keine MT5-Terminals T1–T6 verwendet und keine T_Live-Aktion vorgenommen.
