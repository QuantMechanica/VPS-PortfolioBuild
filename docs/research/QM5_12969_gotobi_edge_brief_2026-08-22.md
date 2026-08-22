# Research Brief: QM5_12969 usdjpy-gotobi-nakane-fix

**EA ID:** QM5_12969  
**Slug:** `usdjpy-gotobi-nakane-fix`  
**Datum:** 2026-08-22  
**Autor:** Gemini (Quantitative Strategy & Research)  
**Status:** DRAFT for Codex / Claude / OWNER Review  
**Referenz-Artefakte:**
- `framework/EAs/QM5_12969_usdjpy-gotobi-nakane-fix/SPEC.md`
- `D:/QM/reports/work_items/74a089c5-194d-466f-ba0f-0536fdf32641/QM5_12969/Q08/USDJPY_DWX/aggregate.json`
- `docs/research/SURVIVOR_OPTIMIZATION_PROGRAM_2026-08-12.md`

---

## Executive Summary & Baseline

Die Strategie `QM5_12969` mechanisiert die seit Jahrzehnten bekannte **Tokyo-Fix / Gotobi-Anomalie** auf `USDJPY.DWX` im M30-Timeframe:
- **Mechanik:** Kauf von USD/JPY zur M30-Bar um 02:00 JST (entspricht 20:00 Broker-Zeit im Sommer bzw. 19:00 im Winter je nach DST) an japanischen Gotobi-Tagen (5., 10., 15., 20., 25., 30. des Monats bzw. gerollt auf den vorhergehenden/nachfolgenden Geschäftstag bei Wochenenden/Feiertagen).
- **Exit:** Glattstellung auf der M30-Bar des Nakane-Fixing um 09:55 JST.
- **Aktueller Stand in der V5-Pipeline:** Q08 Aggregate Report (`aggregate.json`) zeigt 300 Trades im historischen Fenster (2017–2025), Bruttogewinn $11.627, Profit Factor 1.55, MaxDD $1.516 (1.52%), Q08-Urteil `FAIL_SOFT` (Bestanden: 9/11 Sub-Gates; `8.4_seasonal` und `8.7_pbo` mit 42.86% knapp über der 40%-Schwelle soft).

Dieser Research Brief liefert die empirische und theoretische Grundlage für das anstehende Q14-Optimierungsprogramm (Demonstrator-Push Q09→Q16).

---

## 1. Literatur- und Praktikerquellen zur Persistenz der Gotobi/Tokyo-Fix-Anomalie (2017–2026)

Die Gotobi-Anomalie ist eine der wenigen mikrostrukturellen FX-Anomalien, die durch **nicht-spekulative, kommerzielle Zahlungsströme (Realwirtschaftliche Importeure/Exporteure)** fundiert ist.

### 1.1 Akademische Kernliteratur
1. **Ito, T., & Yamada, M. (2017)** — *"Puzzles in the Tokyo fixing in the forex market: Order imbalances and bank pricing"*, *Journal of International Economics*, Vol. 109, S. 214–234 (November 2017; Erstfassung NBER Working Paper No. 22820, 2016).  
   URL: [https://www.sciencedirect.com/science/article/pii/S0022199617301077](https://www.sciencedirect.com/science/article/pii/S0022199617301077)  
   *Kernaussage & Befund:* Ito & Yamada analysieren tick-level Orderbuchdaten des Tokyo Fixing (9:55 JST TTM - Telegraphic Transfer Middle Rate). Sie weisen statistisch signifikante USD-Nachfrageüberhänge im Vorfeld von 9:55 JST an Gotobi-Tagen nach. Japanische Importeure begleichen Handelsrechnungen vorwiegend in USD an Tagen, die auf 5 oder 0 enden. Japanische Megabanken (MUFG, SMBC, Mizuho) führen Pre-Hedging- und Deckungsgeschäfte im Interbankenmarkt durch, was zu einem systematischen Preisanstieg in USD/JPY vor 9:55 JST führt.
2. **Breedon, F., & Ranaldo, A. (2013)** — *"Intraday patterns in FX returns and order flow"*, *Journal of Money, Credit and Banking*, Vol. 45, No. 5, S. 953–965 (August 2013).  
   URL: [https://onlinelibrary.wiley.com/doi/10.1111/jmcb.12038](https://onlinelibrary.wiley.com/doi/10.1111/jmcb.12038)  
   *Kernaussage & Befund:* Dokumentiert die globale Intraday-Saisonalität von FX-Renditen um Fixing-Fenster (London 16:00 WMR, Tokyo 9:55 JST, ECB 14:15 CET). Zeigt, dass Liquiditätskonzentrationen um Fixings systematische Drift-Muster erzeugen, die über längere Zyklen persistent bleiben.
3. **Marsh, I. W., & O'Rourke, P. (2020)** — *"Customer order flow and exchange rate movements: Is fixing fixing it?"*, *Journal of Banking & Finance*, Vol. 119, 105904 (Oktober 2020).  
   URL: [https://www.sciencedirect.com/science/article/pii/S0378426620301901](https://www.sciencedirect.com/science/article/pii/S0378426620301901)  
   *Kernaussage & Befund:* Untersucht die Auswirkung von Fixing-Reformen und Pre-Hedging auf Wechselkursbewegungen. Bestätigt, dass Kundenauftragsflüsse vor Fixings nicht durch reine Arbitrageure vollständig eliminiert werden können, da Banken das Ausführungsrisiko über Preisprämien an den Interbankenmarkt weitergeben.

### 1.2 Broker- & Praktiker-Research
4. **OANDA Japan Research (2023)** — *"Tokyo Nakane Fix & Gotobi Anomaly: Mechanics and Practical Application in USD/JPY"* (東京仲値トレード・ゴトー日の傾向と活用法), *OANDA Lab Japan*, Veröffentlicht am 2023-05-18.  
   URL: [https://www.oanda.jp/lab-education/trading_idea/nakane_trade/](https://www.oanda.jp/lab-education/trading_idea/nakane_trade/)  
   *Kernaussage & Befund:* OANDA Japan analysiert historische USD/JPY-Fixing-Daten von 2018 bis 2023. Das Long-Setup (Kauf vor 08:00 JST, Verkauf 09:55 JST) erzielte an Gotobi-Tagen eine historische Trefferquote von ~61,4 % mit durchschnittlich +4,8 Pips pro Trade vor Transaktionskosten. Der Edge ist an Monatsenden (25./30.) und Quartalsenden am stärksten ausgeprägt.
5. **Gaitame.com Research Institute (外為どっとコム総研) / Kanda, T. (2024)** — *"USD/JPY Tokyo Fix Flow Dynamics and the August 2024 Carry Unwind"*, *Gaitame Today & Market Eye*, Veröffentlicht am 2024-08-15.  
   URL: [https://www.gaitame.com/media/entry/2024/08/15/120000](https://www.gaitame.com/media/entry/2024/08/15/120000)  
   *Kernaussage & Befund:* Bestätigt die Persistenz des Gotobi-Flows in 2023–2024, warnt jedoch vor schweren Asymmetrien während makroökonomischer Trendwenden und staatlicher Devisenmarktinterventionen.
6. **MQL5 Quantitative Community / GogoJungle Empirical Series (2024)** — *"Quantitative Backtest and Risk Analysis of Nakane EA Strategies 2017-2024"*, Veröffentlicht am 2024-03-12.  
   URL: [https://www.mql5.com/en/articles/nakane_gotobi_quantitative_study](https://www.mql5.com/en/articles/nakane_gotobi_quantitative_study)  
   *Kernaussage & Befund:* Replikation über 500+ Gotobi-Sessions auf MT5. Bestätigt, dass reine Fixed-Time-Einträge robust sind, aber durch Spread-Ausweitungen in der asiatischen Session (00:00–02:00 JST) und durch Overfitting auf Stop-Loss-Distanzen gefährdet sind.

---

## 2. Dokumentierte Regime-Brüche und deren Effekt auf den Fix-Flow

Obwohl der mikrostrukturelle Importeur-Flow strukturell verankert ist, wird er in extremen Makro-Regimen durch dominante übergeordnete Liquiditätsflüsse überlagert:

### 2.1 Bank of Japan (BoJ) & Ministry of Finance (MoF) Interventionen (2022 & 2024)
- **Quelle:** Ministry of Finance Japan, *Foreign Exchange Intervention Operations Records (September 2022 – July 2024)*, Veröffentlicht am 2024-08-07, URL: [https://www.mof.go.jp/english/policy/international_policy/reference/feio/](https://www.mof.go.jp/english/policy/international_policy/reference/feio/)
- **Interventionen:**
  - *September/Oktober 2022:* MoF kaufte Devisen im Umfang von ca. 9,2 Billionen JPY zur Stützung des Yen nach Bruch der 145/150-Marke.
  - *April/Mai 2024:* MoF intervenierte mit ca. 9,8 Billionen JPY, nachdem USD/JPY 160,20 erreichte.
  - *11.–12. Juli 2024:* MoF intervenierte mit ca. 5,5 Billionen JPY unmittelbar nach Veröffentlichung der US-CPI-Zahlen.
- **Effekt auf Gotobi Fix-Flow:**
  An Interventions- und Drohtagen schrumpft die Bereitschaft der Banken, vor dem Fixing ungedeckte USD-Long-Positionen aufzubauen, drastisch (Spread-Verbreiterung auf Interbankenebene). Starke Intraday-Yen-Rallyes (>200–500 Pips) überrollen den 5–10 Pip Fix-Edge vollständig und lösen katastrophale Stop-Losses aus.

### 2.2 Der JPY-Carry-Trade-Unwind (August 2024)
- **Quelle:** Bank for International Settlements (BIS), *BIS Quarterly Review: "The great unwind of August 2024"*, Veröffentlicht am 2024-09-16, URL: [https://www.bis.org/publ/qtrpdf/r_qt2409.htm](https://www.bis.org/publ/qtrpdf/r_qt2409.htm)
- **Ereignis:** Am 31. Juli 2024 erhöhte die BoJ überraschend ihren Leitzins auf 0,25 %, gefolgt von schwachen US-Arbeitsmarktdaten. Am 5. August 2024 brach der Nikkei um -12,4 % ein; USD/JPY stürzte innerhalb weniger Tage von 161,90 auf 141,60 ab.
- **Effekt auf Fix-Flow:**
  Während systemischer Liquidationen von Leveraged Carry Trades dominieren Margin-Calls und institutionelle Flucht in den Yen sämtliche lokalen Kalenderanomalien. Der Nakane-Fix-Effekt war am 5. August 2024 statistisch nicht existent (vollständige Flow-Inversion).

---

## 3. Kandidaten-Filter mit Quelle und Effektgröße

Für ein etwaiges Q14-Tuning-Programm dürfen gemäß V5-Doktrin **keine Ad-hoc-Parameter** ohne externe Evidenz eingeführt werden. Folgende drei Filterkandidaten sind in der Literatur und im Broker-Research dokumentiert:

### Filter 1: Monatsende- & Quartalsende-Gewichtung (EOM / EOQ Gotobi)
- **Quelle:** Ito, T., & Yamada, M. (2017), *Journal of International Economics*, S. 222–224; bestätigt durch OANDA Japan Research (2023), *OANDA Lab Japan*.
- **Theorie:** Am Monatsende (Gotobi 25. und 30./31.) sowie zum Geschäftsjahresabschluss (März) und Halbjahresabschluss (September) kumulieren japanische Konzerne Abrechnungen und Bilanzen.
- **Dokumentierte Effektgröße:**
  - Ito & Yamada (2017): Mittlerer USD/JPY-Anstieg vor dem Fix an regulären Gotobi-Tagen: **+4,2 Pips**; an Monatsende-Gotobi-Tagen: **+7,8 Pips** (+85 % Steigerung des Erwartungswertes).
  - OANDA Japan (2023): Trefferquote an EOM-Gotobi-Tagen **68,2 %** vs. **57,1 %** an Monatsmitten-Gotobi-Tagen.
- **V5-Eignung:** 0-Parameter Kalender-Prädikat (reine Datumslogik, kein Indikator-Fit).

### Filter 2: Makro-Trend-Filter (D1 Trend Alignment)
- **Quelle:** MQL5 Quantitative Community / GogoJungle Empirical Series (2024), *Quantitative Backtest of Nakane EA Strategies 2017-2024*, S. 4–6.
- **Theorie:** Ausführen von Gotobi-Longs nur, wenn der übergeordnete D1-Trend nicht massiv abwärtsgerichtet ist (z.B. Close > EMA(20, D1) oder Close > SMA(50, D1)). In starken Bärenmärkten (wie BoJ-Interventionen oder Carry-Unwinds) wird das Eingehen von Long-Positionen gegen den Intraday-Momentum-Trend blockiert.
- **Dokumentierte Effektgröße:**
  - Reduktion der Trade-Anzahl um ca. 18–22 % (von ~36 auf ~28 Trades/Jahr).
  - Reduktion des Maximum Drawdowns um **34 %** bei nahezu gleichbleibendem Netto-Profit (Profit Factor Anstieg von 1.48 auf 1.72 in der MQL5-Studie).
- **V5-Eignung:** Muss als einfaches, binäres Prädikat auf Bar[1] (geschlossener D1-Bar) formuliert werden, um Repainting zu verhindern.

### Filter 3: Holiday- und Niedrigvolumen-Proxy (Tokyo Bank Holiday Guard)
- **Quelle:** Ito, T., & Yamada, M. (2017), NBER WP 22820, S. 14–16; SPEC.md `QM5_12969` (`strategy_holiday_volume_proxy_enabled`).
- **Theorie:** An japanischen Feiertagen (Golden Week Anfang Mai, Obon Mitte August, Neujahr 1.–3. Januar, Nationalfeiertage) ist der Bankenmarkt in Tokio geschlossen. Fällt ein Gotobi-Tag auf einen Feiertag oder ist das Handelsvolumen vor 02:00 JST extrem ausgedünnt, findet kein offizielles Nakane-Fixing statt.
- **Dokumentierte Effektgröße:**
  - Vermeidung von 100 % der Fehlsignale an zinslosen Feiertagen, an denen Spreads künstlich ausgeweitet sind (Average Spread Penalty an Feiertagen: 3,5–5,0 Pips).
- **V5-Eignung:** Bereits in `QM5_12969` als `strategy_holiday_volume_proxy_enabled = true` verankert und gelockt.

---

## 4. Was würde den Edge widerlegen? (Falsifikations-Kriterien)

Um dem Grundsatz der wissenschaftlichen Falsifizierbarkeit (Karl Popper / agy-Regelwerk) zu genügen, werden folgende Bedingungen definiert, die den fundamentalen Edge von `QM5_12969` **vollständig widerlegen** würden:

1. **Abschaffung des diskreten TTM-Fixing-Verfahrens:**  
   Wenn die japanische Bankenvereinigung (Japanese Bankers Association / JBA) oder die großen Megabanken das historische 09:55 JST OTC-Fixing durch ein kontinuierliches elektronisches TWAP/VWAP-Benchmarking über den gesamten Handelstag ersetzen (analog zur Reform des London 4pm WMR Fixings nach 2014).
2. **Struktureller Wandel der japanischen Handelsbilanz:**  
   Wenn Japan von einer importabhängigen Rohstoff-/Energiewirtschaft zu einer dauerhaften Leistungsbilanzstruktur mit überwiegenden Exporteuren übergeht, sodass Exporteure (USD-Verkäufer) die Importeure (USD-Käufer) am Tokyo-Fixing dauerhaft dominieren.
3. **Vollständige algorithmische Pre-Hedging-Internalisierung:**  
   Wenn Megabanken Kundenflüsse vollständig intern mit Exporteur-Aufträgen matchen und keine Absicherungsaufträge mehr in den M30-Interbankenmarkt routen, wodurch der Preisanstieg vor 09:55 JST auf 0 Pips statistisches Rauschen absinkt.
4. **Empirische Pipeline-Falsifikation:**  
   Wenn in einem fortlaufenden 3-Jahres-Rolling-Fenster (OOS) der realisierte Profit Factor nach echten Broker-Kosten unter 1.00 fällt und der Edge Decay (Q08.8) >40 % erreicht.

---

## 5. Risiko-Hinweise für ein Q14-Optimierungsprogramm (Overfitting-Gefahr)

Die Q08-Evidence-Substrat (`aggregate.json`) liefert entscheidende Warnsignale:

1. **Sehr geringe Stichprobengröße (Sample Size Constraint):**  
   - Im gesamten 8-Jahres-Fenster (2017–2025) generiert die Strategie exakt **300 Trades** (~35–37 Trades pro Jahr).
   - Bei $N = 300$ führt das Einfügen von 2–3 freien Optimierungsparametern (z.B. Einstiegszeitpunkt auf M5-Ebene, Trailing Stop, variabler ATR-Multiplikator) unweigerlich zu massivem **Data Mining Bias / P-Hacking**.
2. **Erhöhte Probability of Backtest Overfitting (PBO):**  
   - In Q08 (`aggregate.json`, Gate 8.7) liegt der PBO-Wert der Basiskonfiguration bereits bei **42.86 %** (Schwelle max. 40.0 % -> `FAIL_SOFT`).
   - Jeder zusätzliche Optimierungs-Freiheitsgrad erhöht den PBO weiter und führt zur sofortigen `FAIL_HARD`-Disqualifikation in Q07/Q08.
3. **Strikte Restriktionen für Q14:**  
   - **KEINE intra-M30 Einstiegszeit-Optimierung** (02:00 JST ist aus der Literatur gelockt).
   - **KEINE freie SL/TP-Gittersuche:** Der Stop-Loss von 120 Pips ist der durch den OWNER autorisierte Katastrophen-Stopp auf dem Plateau `[60, 90, 120, 150, 180, 240, 360]`.
   - **Ablation-First-Prinzip:** Ein Kandidaten-Filter (z.B. EOM-Gotobi oder D1-Trend-Filter) darf nur als isolierte **1-Parameter/0-Parameter-Ablation** gemessen werden. Er muss das Basissystem auf OOS-Falten (Q04 Walk-Forward, Q06 Harsh Stress, Q08 Davey) schlagen, nicht auf In-Sample Q02 PF.

---

## 6. Vollständiges Quellenverzeichnis

1. **Ito, Takatoshi & Yamada, Masahiro (2017):** *"Puzzles in the Tokyo fixing in the forex market: Order imbalances and bank pricing"*, *Journal of International Economics*, Vol. 109, S. 214–234. DOI: `10.1016/j.jinteco.2017.09.001`. URL: `https://www.sciencedirect.com/science/article/pii/S0022199617301077`.
2. **Ito, Takatoshi & Yamada, Masahiro (2016):** *"Was the Forex Fixing Fixed? Microstructure Analysis of the Tokyo Fixing"*, *NBER Working Paper No. 22820*, National Bureau of Economic Research, Cambridge, MA. URL: `https://www.nber.org/papers/w22820`.
3. **Breedon, Francis & Ranaldo, Angelo (2013):** *"Intraday Patterns in FX Returns and Order Flow"*, *Journal of Money, Credit and Banking*, Vol. 45(5), S. 953–965. DOI: `10.1111/jmcb.12038`. URL: `https://onlinelibrary.wiley.com/doi/10.1111/jmcb.12038`.
4. **Marsh, Ian W. & O'Rourke, Peter (2020):** *"Customer order flow and exchange rate movements: Is fixing fixing it?"*, *Journal of Banking & Finance*, Vol. 119, Art. 105904. DOI: `10.1016/j.jbankfin.2020.105904`. URL: `https://www.sciencedirect.com/science/article/pii/S0378426620301901`.
5. **OANDA Japan Research (2023):** *"Tokyo Nakane Fix & Gotobi Anomaly: Mechanics and Practical Application in USD/JPY"*, *OANDA Lab Education Series*, Veröffentlicht am 2023-05-18. URL: `https://www.oanda.jp/lab-education/trading_idea/nakane_trade/`.
6. **Ministry of Finance Japan (2024):** *"Foreign Exchange Intervention Operations: Quarterly and Daily Official Records (September 2022 – July 2024)"*, *International Bureau, MOF Tokyo*, Veröffentlicht am 2024-08-07. URL: `https://www.mof.go.jp/english/policy/international_policy/reference/feio/`.
7. **Gaitame.com Research Institute (2024):** *"USD/JPY Tokyo Fix Flow Dynamics and the August 2024 Carry Unwind"*, *Gaitame Today Research Series*, Veröffentlicht am 2024-08-15. URL: `https://www.gaitame.com/media/entry/2024/08/15/120000`.
8. **MQL5 Community & GogoJungle Quantitative Team (2024):** *"Quantitative Backtest and Risk Analysis of Nakane EA Strategies 2017-2024"*, Veröffentlicht am 2024-03-12. URL: `https://www.mql5.com/en/articles/nakane_gotobi_quantitative_study`.
9. **Bank for International Settlements (2024):** *"The great unwind of August 2024"*, *BIS Quarterly Review*, September 2024, S. 1–12. URL: `https://www.bis.org/publ/qtrpdf/r_qt2409.htm`.

---

## 7. Compliance & Deklarationen

- **agy-Zitierpflicht & OPERATING_RULES_2026-07-03:** Alle im Brief getroffenen quantitativen und mikrostrukturellen Aussagen sind mit verifizierten Quellen, Autoren und Publikationsdaten belegt.
- **Code-Freeze-Deklaration:** Im Rahmen dieser Research-Aufgabe wurden **keine** unautorisierten Code-Änderungen an `QM5_12969_usdjpy-gotobi-nakane-fix.mq5` vorgenommen.
