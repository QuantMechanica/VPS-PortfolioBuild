# CEO-Workplan: Vom 13-Sleeve-Book zum Multi-Venue-EA-Portfolio

**Datum:** 2026-07-02 · **Autor:** Claude (CEO-Mandat OWNER) · **Ziel-Venues:** DarwinexZero (live), FTMO, The5%ers

## Zielbild

Ein EA-Portfolio aus unterschiedlichen Strategieklassen auf unterschiedlichen Instrumenten, das
(a) Prop-Challenges seriell besteht (FTMO → 5%ers), (b) auf DXZ konsistent mit geringem
Drawdown skaliert, (c) als Krönung mindestens eine robuste **mechanische Swing-Strategie**
enthält. Messlatte pro Book: MaxDD < 10% (FTMO-kompatibel), Sharpe > 1.5, max.
Pair-Korrelation < 0.3, Ziel-Erreichbarkeit (Round24-Screen) > 60%.

## Fundament (Ist-Stand, Evidenz 2026-07-02)

- **Live:** 13-Sleeve D2-c Book auf Darwinex (Konto 4000090541) seit 28.06., VaR-gefüllt →
  Wachstum NUR über orthogonale Sleeves, nicht über Risiko.
- **Pipeline-Ausbeute (alle Zeit, ex-INFRA):** Q04-Überleben: Metall **8.6%**, Index **5.4%**,
  Forex **1.0%**, Commodity 0.6% (kleine Basis). **63% der Factory-Rechenzeit ging in Forex —
  die schlechteste Klasse.** Mechanik-Familien: Mean-Reversion 5.6% > Trend 3.4% >
  Session 1.7% > Basket 1.2%. 47 EAs erreichten jemals Q05+.
- **Q08:** 0 Hard-PASS by design; FAIL_SOFT→Portfolio-Track (100 EAs) ist die Book-Quelle.
- **Seasonality/Calendar: 0/88** — ABER: vor DL-076 (Low-Freq-Q04) getestet und vor den
  heutigen Fidelity-Fixes (12836/12844/12846/12847). Klasse gilt als UNGETESTET, nicht tot.

## Workstreams

### WS1 — Kapitalallokation der Factory (sofort, Claude + Pump-Konfiguration)
1. Build-/Testbudget umsteuern: **Index/Metall/Commodity-Karten priorisieren**, Low-Freq zuerst
   (priority_score-Gewichte + Build-Reihenfolge).
2. Forex nur noch: Low-Freq (<~50 T/Jahr), Baskets/Cointegration, JPY/CHF-Cross-Klasse
   (Book-Lücke). High-Freq-FX-Karten werden NICHT mehr gebaut (Q04-Beweis: 1.0%).
3. Basis: Card-Inventur-Report (läuft; Prune-Liste + Prioritätsliste folgt heute).

### WS2 — T-WIN-Schleife zu Ende führen (Claude + Codex, läuft)
Shift-Fix ist drin; korrigierte 1y-Läufe 2024 + 2023, dann Exhaustion-Sweep. Klare
Abbruchkante: wenn nach Sweep + Sizing-Fix 2023 UND 2024 negativ → Klasse dokumentieren,
archivieren, Ressourcen zu WS3. Kein Endlos-Tuning.

### WS3 — Die Swing-Initiative (der "Traum", höchste Neubau-Priorität)
Evidenz: Low-Freq strukturelle Edges sind UNSERE Überlebensklasse (DL-070-Track existiert).
1. **agy:** systematische YouTube-/Quellen-Recherche NUR auf mechanische Swing-Strategien
   (D1/H4, Haltedauer Tage-Wochen, regelbasiert, keine Diskretion): Kanäle, Bücher, Paper.
2. **Claude:** Synthese in Cards (Ziel: 10 Swing-Kandidaten auf Index/Metall/Commodity/FX-Cross).
3. **Codex:** Builds; Pipeline beweist. Q04-PASS_LOWFREQ + Q08-Soft-Track sind dafür kalibriert.
4. Bestehende Assets zuerst: 12567-Klasse (cum-rsi2 Ports), Calendar-Neubewertung
   (12893-12909-Welle), XAG/UK100/ORB-Karten aus der Missing-Class-Recherche.

### WS4 — Prop-Firm-Track (FTMO zuerst, dann 5%ers) — **HOCHGESTUFT 2026-07-03**

**OWNER-Ratifizierung 07-03: WS4 ist gleichrangiges DESIGN-Ziel, nicht nur Screening**
(Operating Rules 18/19). DXZ ist VaR-gefüllt; Wachstum kommt aus Challenges, dort bindet
Target-Coverage. Konsequenz: Karten werden GEZIELT für Renditedichte + Intraday-DD gebaut.

1. **Prop-Track-Karten-Slate 1 aktiv:** QM5_12985 (NDX/SP500/GDAXI RSI2-Shorthold),
   12986 (GDAXI ORB day-flat, dient Task #17), 12987 (XTI cum-RSI2, dient Task #16),
   12988 (XTI EIA-Inventory-Day, event-driven/orthogonal). Design-Spec: Dichte
   ≥~25 Tr/Jahr/Symbol, Index/Commodity (Kommission irrelevant), Day-Flat/strukturelle
   Stops. Slate-ID: CEO-PROPTRACK-SLATE-2026-07-03.
2. **Round24-Admission-Screen** (Tool fertig, 97e655fe) über den GESAMTEN Q08-Soft-Pool +
   Book-Sleeves laufen lassen → Ranking nach Ziel-Erreichbarkeit + Breach-Risiko.
3. Intraday-DD/MAE-Capture (Codex-Task 1d72d68a) abschließen → FTMO-DD-Regeln exakt simulieren.
4. FTMO-Book-Komposition: bestehendes Round24-13-Leg als Benchmark (57% min-robust);
   jede Änderung muss COMBINED schlagen. Binding constraint = Zielerreichung, nicht Risiko →
   Sleeves mit höherer Frequenz/Amplitude auf Index (billige Kosten) gezielt ergänzen.
5. 5%ers-Regelwerk als Variante des Screens (Codex, klein) — gleiche Maschinerie.

### WS5 — DXZ-Book-Pflege (kontinuierlich)
Q09-Admission (DL-075/078) läuft; Kandidaten aus Rescue-Wave (10569 XAU, 10115 GDAXI,
Redumps) + jede neue Q08-FAIL_SOFT → Korrelations-Check → OWNER-Review Q12. Kein
Sizing-Wachstum (VaR voll).

### WS6 — Infrastruktur-Härtung (Codex, niedrig-prio aber verzinst sich)
1. Evidence-Doc-Stranden in Worktrees fixen (heute 7 Docs gerettet — Prozessfehler).
2. run_smoke: post-run-Pump-Hook opt-out für dedizierte Testfenster (heutige Lektion).
3. Lot-Sizing-Architektur T-WIN-Klasse (Equity-basiert vs. Risikobudget) — OWNER-Design-Entscheid
   vorbereiten.

## Kadenz & Governance

- **Täglich:** Funnel-Deltas + Quota (bestehende /update-Routine); Verdikt-Flow > 10 Q03+/6h.
- **Wöchentlich:** Book-Report (Sharpe/DD/Korrelationen), FTMO-Screen-Top-10, Kill-Liste
  (Karten/EAs ohne Perspektive), Neubau-Slate (max. 10 Cards/Woche — Qualität vor Volumen).
- **Gates unverändert:** Q04 net-of-cost bleibt der Richter; Gates sind BEWUSST konservativ
  (OWNER-Direktive) — wir bauen selektiver, nicht die Gates weicher.
- **Agenten-Split:** agy = Video/Quellen-Recherche; Codex = Code/Builds/Tools; Claude =
  Synthese, Reviews, Priorisierung, Portfolio-Entscheidungen; OWNER = Q12+, T_Live, Risiko.

## Meilensteine

| # | Meilenstein | Kriterium | Ziel |
|---|---|---|---|
| M1 | Backlog trianguliert | Prune-/Prio-Liste umgesetzt, Build-Queue neu sortiert | diese Woche |
| M2 | T-WIN-Entscheid | profitabel ODER sauber archiviert | diese Woche |
| M3 | FTMO-Screen komplett | Q08-Pool + Book gescreent, Top-Book definiert | nächste Woche |
| M4 | Swing-Slate v1 | 10 Swing-Cards approved, Builds laufen | nächste Woche |
| M5 | FTMO-Challenge-Start | OWNER-Go auf Basis Screen>60% min-robust | nach M3+M4 |
| M6 | Mechanische Swing-Strategie live-reif | 1 Swing-EA durch Q08-Soft + Admission | 4-6 Wochen |
