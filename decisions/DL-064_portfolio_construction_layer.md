# DL-064 — Portfolio-Construction-Layer: Q11 von Platzhalter zu echter Antikorrelations-Maschinerie

**Date:** 2026-06-01
**Status:** Decided (OWNER + Claude) — ratified 2026-06-01
**Supersedes:** none
**Related:** DL-062 (Zero-Trade-Rework), `project_qm_backtests_cost_free_2026-05-29`
(Kosten-Blocker), `tools/strategy_farm/phase_ids.py` (Q11 Phasenname),
Kaspareit-Trading "Portfolio L" (externe Blaupause, YouTube ZQ9hDk9Bs7Y)

## Kontext

Eine externe Blaupause ("Portfolio L" von Kaspareit-Trading) formuliert exakt
unsere Mission in einem Satz: Sicherheit entsteht nicht durch den perfekten
Einzel-EA, sondern durch ein **unkorreliertes Ensemble** mittelmäßiger, aber
robuster Strategien (Ray-Dalio-Logik: Antikorrelation). Bei 12 EAs über 6 Märkte
addieren sich die Gewinne, aber **nicht** die Drawdowns — eine Einzelstrategie
mit ~10 % DD wird im Portfolio zur tragenden Säule, weil sie performt, wenn
andere schwächeln. Gemeldete Aggregat-KPIs: Portfolio-DD 5,27 % < manche
Einzel-DD, Sharpe 2,46.

**Befund aus dem aktuellen Code (Evidenz):**

- Unsere Pipeline ist vollständig **Einzel-EA-zentriert**. Alle 14 Gates
  (Q00–Q13) bewerten *eine* EA gegen *absolute* Schwellen.
- `phase_ids.py` führt **Q11 "Portfolio Construction"** als Phasennamen, aber
  es existiert **keine Portfolio-Maschinerie**. Ein Grep über die gesamte
  Controller-Logik (`correlat|portfolio|ensemble|allocat`) liefert nur
  Einzel-EA-SPECs plus einen einzigen Platzhalter: `farmctl.py:7112` definiert
  "Portfolio-Kandidat = mindestens 1 Symbol durch". Das ist die gesamte
  heutige Portfolio-Logik.
- Es gibt **keine** Korrelationsmatrix, keine Antikorrelations-Auswahl, kein
  Portfolio-Drawdown, keine Allokation/Gewichtung, keine Portfolio-Sharpe.

**Wichtig — was wir bereits haben und worüber wir die Blaupause übertreffen:**
Das von Kaspareit als QS verkaufte Triple (Walk-Forward, Monte Carlo,
Out-of-Sample) ist bei uns bereits härter abgebildet: Q04 WFA+Commission,
Q05/Q06 Stress MEDIUM/HARSH, Q07 Multi-Seed, Q08 Davey (10 Sub-Gates), Q10
Full-History-OOS. Die Lücke ist **nicht** die Per-EA-Robustheit. Die Lücke ist
zu 100 % die **Portfolio-Schicht** plus die Neuausrichtung der Stufen davor
(gerichtetes Research + portfolio-relative Aufnahme).

## Entscheidung

**Q11 wird von einem Phasennamen zu einer echten Portfolio-Construction-Schicht
ausgebaut. Der Erfolg der Strategy Farm wird am Portfolio (Sharpe / DD /
Antikorrelation) gemessen, nicht an der Anzahl bestandener Einzel-EAs. Die
Per-EA-Robustheits-Gates bleiben hart; die Per-EA-*Profitabilitäts*-Schwelle
wird portfolio-relativ.**

Diese DL ist ein **Initiativ-Beschluss** (richtungsweisend, reversibel) — sie
autorisiert die Spezifikation und den Bau, nicht eine fertige Implementierung.
Code-Bewegung erfolgt erst nach OWNER-Ratifizierung und nach Gate-0 (s. u.).

## Gate-0 (harte Vorbedingung) — ✅ ERFÜLLT, verifiziert 2026-06-01

**Begründung:** Ohne Kostenrechnung ist jedes Portfolio-Aggregat aus
Brutto-Equity-Kurven überzeichnet — eine "Sharpe 2,46" wäre gross-of-costs.
Ursprungslage (`project_qm_backtests_cost_free_2026-05-29`): jeder MT5-Backtest
verrechnet $0 Kommission + $0 Swap auf `.DWX`-Custom-Symbole (Net==GrossP+GrossL,
6+ Reports), weil die Groups-Datei `Darwinex-Live_real.txt` keine `.DWX`-Pfade
matcht.

**Gelöst — nicht über die Groups-Datei, sondern EA-seitig.** Die Groups-File-Route
(Codex-Task `f308fe3f`, Pin `d04f2611`) wurde verworfen (RECYCLE, 3 Backtests
weiter $0) — `.DWX` sind Custom-Symbole, die die Groups-Datei nie governt. Der
**bewährte Fix ist EA-seitige simulierte Kommission** (`InpQMSimCommissionPerLot`
in `QM_Common.mqh`, Commit `541bfdd8`, **auf origin/main**): jeder schließende
Deal wird mit `$/lot` belastet, der EA emittiert `pf_net` nach
`Common\Files\QM`, und `q04_walkforward.py` fällt das Verdikt auf `pf_net`
(nicht den Brutto-Report-PF). Konstante **`COMMISSION_PER_LOT_ROUND_TRIP = 7.00`**
gelockt; Bug #6 (Expert-Pfad `QM\<dir>`) und #7 (`-Period` variabel) gefixt.

**Laufzeit-Evidenz (Farm-State-DB, 2026-06-01):** Q04 läuft netto-of-cost. Alle
3687 INFRA_FAIL sind Alt-Last (26.–29.05., vor dem Fix); **null INFRA_FAIL seit
dem Fix**. Netto-PASS fließen täglich: 29.05 = 5, 30.05 = 10, 31.05 = 10,
01.06 = 7 (laufend). Damit ist die Kosten-Vorbedingung für R-064-3 erfüllt.

**Offen (nicht blockierend für Gate-0, aber für OWNER):** Q02/Q03 bleiben
gross-of-costs Screens — bewusst (Q04 = erstes kostenbewusstes Gate) oder
nachzuziehen? OWNER-Entscheidung, siehe
`docs/ops/Q04_FIFTH_ROOT_CAUSE_commission_mechanism_2026-05-29.md`.

## Bindende Regeln

### R-064-1 — Research-Intake (Q00) wird matrix-gerichtet
Research-Nachfrage wird nicht mehr nur aus dem Reservoir-Floor (≥5 Karten)
abgeleitet, sondern aus **leeren/unterbesetzten Zellen einer Portfolio-Matrix**:
Logik-Typ { Trend, Mean-Reversion, Saison/Volatilität } × Markt-Cluster
{ Forex, Index, Rohstoff } (Mindest-Granularität; verfeinerbar). Der
`agent_router` priorisiert Research für die am dünnsten besetzte Zelle. Ziel:
keine 200 korrelierten Trendfolger. Der Reservoir-Floor bleibt als Untergrenze.

### R-064-2 — Portfolio-relativer Aufnahmepfad (Philosophie-Bruch, kontrolliert)
Die Robustheits-Gates (Q04 WFA, Q05/Q06 Stress, Q07 Multi-Seed, Q08 Davey,
Q10 OOS) bleiben **hart und nicht verhandelbar** — sie sind der Schutz gegen
Overfit-Müll. Die *Rendite*-Schwelle (heute Q02 PF≥1.20/1.30) wird **bedingt**:
Eine EA, die standalone unter Schwelle liegt, aber (a) alle Robustheits-Gates
besteht UND (b) negativ/niedrig zum bestehenden Buch korreliert UND (c)
Portfolio-Sharpe oder Portfolio-DD messbar verbessert, erhält einen
Aufnahmepfad. Eine standalone unter Schwelle liegende EA wird **nie** allein
auf Basis von (a) aufgenommen — (b) und (c) sind zwingend.

### R-064-3 — Q11 baut echte Maschinerie
Q11 implementiert vier Komponenten:
1. **Korrelations-Engine** — pro EA die Return-/Equity-Kurve, auf einen
   gemeinsamen Kalender und vergleichbare Test-Fenster normalisiert →
   Korrelationsmatrix über alle Gate-Passierer. Rohmaterial existiert bereits:
   die `TRADE_CLOSED`-JSONL-Streams je EA unter
   `Common\Files\QM\q08_trades\<ea>_<sym>.jsonl` (Q08-Fix `5e574572`). Es fehlt
   der Aggregator, der daraus die Equity-Kurven-Matrix baut.
2. **Portfolio-Assembler** — wählt/gewichtet eine Teilmenge, sodass der
   Portfolio-DD unter Zielbindung bleibt (Mission: 5 % daily / 20 % total) bei
   maximaler Portfolio-Sharpe.
3. **Portfolio-KPI-Artefakt** — aggregierter Net, Portfolio-Max-DD,
   Portfolio-Sharpe als First-Class-Output (nicht 12 Einzelreports). Gate-0
   ist Vorbedingung.
4. **Portfolio-Monte-Carlo** — Resampling auf der *kombinierten* Equity (nicht
   nur Per-EA-Trade-Reshuffle aus Q05/Q06) → Verteilung des Portfolio-DD.

### R-064-4 — Live-Deployment als Portfolio-Manifest, nicht Einzel-EA
T_Live-Promotion wird Freigabe eines **Portfolio-Manifests mit Gewichten**
(Allokationsmodell: equal-risk-contribution / vol-getargetet). Die
Risiko-Bindung gilt am **Konto-Level**, nicht pro EA. Die Magic-Number-Registry
(`ea_id*10000+slot`) trägt Mehr-EA-auf-einem-Konto bereits. Die T_Live-Authority
bleibt unverändert OWNER + Claude (Hard Rule); diese Regel ändert nur das
*Objekt* der Freigabe (Portfolio statt Einzel-EA), nicht die Autorität.

### R-064-5 — Periodisches Portfolio-Re-Fit (neuer wiederkehrender Prozess)
Korrelationen sind nicht stationär (Regime-Shift). Ein periodisches Re-Fit
rechnet die Korrelationsmatrix neu, rebalanciert die Gewichte und retiret
zerfallene Sleeves. Kadenz im Implementierungs-Spec festzulegen. Ein statisch
einmal optimiertes Buch ist selbst overfit-anfällig — diese Regel ist die
Antwort darauf.

### R-064-6 — Portfolio-Demo-Burn-In vor T_Live
Analog zu Kaspareits Demo-Beta-Phasen: das *zusammengesetzte* Buch läuft als
Portfolio-Burn-In auf Demo (unseen forward data), bevor es nach T_Live geht.
Ergänzt Q13 (Per-EA Live-Burn-In) um eine Portfolio-Ebene; ersetzt es nicht.

## Erfolgsmetrik-Verschiebung

MT5-Saturation bleibt die **Durchsatz**-Metrik (unverändert). Die
**Ergebnis**-Metrik der Farm verschiebt sich von "wie viele EAs durch die Gates"
zu **Portfolio-Sharpe / Portfolio-DD / Anzahl effektiv unkorrelierter Sleeves**.
Dashboards (Cockpit, strategies.html, EA-Detail) erhalten eine Portfolio-View:
Korrelations-Heatmap, kombinierte Equity-Kurve, Portfolio-DD, marginaler
Diversifikationsbeitrag je EA.

## Risiken / Blocker

- **Gate-0 (Kosten) ist nicht verhandelbar.** Brutto-Equity-Aggregate sind
  wertlos. Ohne den Q04-Fix kein vertrauenswürdiges Portfolio.
- **Datendisziplin.** Korrelation braucht kalender-ausgerichtete Equity-Serien
  aus vergleichbaren Fenstern; EAs laufen heute auf unterschiedlichen
  Symbolen/Zeiträumen. Der Aggregator muss auf gemeinsame Fenster normalisieren,
  sonst ist die Korrelationsmatrix Artefakt statt Signal.
- **Antikorrelation ist nicht stationär** — adressiert durch R-064-5, aber das
  Re-Fit darf nicht selbst zu Overfit auf jüngste Korrelation werden.
- **R-064-2 ist ein Philosophie-Bruch** und muss eng begrenzt bleiben (alle drei
  Bedingungen a∧b∧c), sonst öffnet er ein Schlupfloch für schwache EAs.

## Abgelehnte Alternativen

### Alternative 1: Status quo — "1 Symbol durch = Portfolio-Kandidat" beibehalten
Abgelehnt. Das ist keine Portfolio-Konstruktion, sondern eine Einzel-EA-Sammlung.
Es ignoriert Korrelation vollständig und kann ein Buch aus 12 gleichgerichteten
Trendfolgern produzieren, deren DDs sich **addieren** — das genaue Gegenteil der
Mission.

### Alternative 2: Per-EA-Schwellen senken, damit mehr "mittelmäßige" EAs durchkommen
Abgelehnt. Das verwechselt "mittelmäßig aber robust + antikorreliert" mit
"schwach". Senkt man die Robustheits-Gates, lässt man Overfit-Müll durch, der im
Live-Betrieb einbricht. Die Lösung ist portfolio-*relative* Rendite bei
unveränderten Robustheits-Gates (R-064-2), nicht pauschal niedrigere Gates.

### Alternative 3: Kaspareits QS-Protokoll (WFA/MC/OOS) übernehmen
Abgelehnt als redundant — wir haben es bereits in härterer Form (Q04–Q10). Es
gäbe nichts zu übernehmen; die Energie gehört in die Portfolio-Schicht.

## Implementierung (nach Ratifizierung)

1. ~~Diese DL ratifizieren (OWNER).~~ ✅ Ratifiziert 2026-06-01. Registry-Zeile gesetzt.
2. ~~**Gate-0:** Q04-Kommissions-/Swap-Kalibrierung verifizieren.~~ ✅ Erfüllt
   2026-06-01 via EA-seitige Sim-Kommission (`541bfdd8`, auf main); Q04 läuft
   netto, null INFRA_FAIL seit Fix. Siehe Gate-0-Sektion.
3. Portfolio-Matrix-Definition + `agent_router`-Patch (R-064-1).
4. Korrelations-Aggregator auf `q08_trades`-Streams (R-064-3.1) + KPI-Artefakt
   (R-064-3.3, hängt an Gate-0).
5. Portfolio-Assembler + Portfolio-Monte-Carlo (R-064-3.2 / R-064-3.4).
6. Portfolio-relativer Aufnahmepfad in den Gate-Verdict-Pfad (R-064-2).
7. Dashboards Portfolio-View; T_Live-Portfolio-Manifest (R-064-4);
   Re-Fit-Prozess (R-064-5); Portfolio-Demo-Burn-In (R-064-6).
