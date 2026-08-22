# SP-C3 — Konzentrations- und Tail-Limits: Design (Claude/Orchestrator)

Datum: 2026-08-22 · Task `4fab7ffd` · Zone GELB (Design; Durchsetzung Codex;
Schwellen-Ratifikation und jede Live-Gewichtsänderung OWNER/ROT)
Quelle: Consulting-Audit §8 F-05 / §14 H-03 · Schienenplan Track C

## 1 · Prinzip

Die interne Stop-Risk-Summe (Governor, SP-C1) misst, was *geplant* verloren werden
kann. Sie ist blind für **Gleichläufigkeit**: zehn Sleeves, die am selben Tag im
selben Faktor verlieren, reißen ein Konto mit „regelkonformen" Einzelrisiken.
SP-C3 ergänzt (ersetzt nicht) die Stop-Risk-Summe um Konzentrations-Caps und
Tail-Sichtbarkeit über fünf Dimensionen. Alles wird aus **gemessenen Streams**
berechnet (aggregate.json / Trade-Streams der Gate-Kette), nie aus Behauptungen.

## 2 · Die fünf Dimensionen und ihre Messgrößen

| Dim | Schlüssel | Messgröße (pro Buch-Kandidat) |
|---|---|---|
| D1 Symbol | `symbol` | Σ geplantes Stop-Risiko aller Sleeves auf demselbem Symbol |
| D2 Assetklasse | `asset_class` aus `dwx_symbol_matrix.csv` (fx/metals/indices/energy) | Σ Stop-Risiko je Klasse |
| D3 Strategie-Familie | `family_fingerprint` (SP-E2-Clustering; bis dahin: Karten-Slug-Stamm) | Σ Stop-Risiko je Familie |
| D4 Session | dominante Entry-Session aus Entry-Zeit-Histogramm (Asia/EU/US, Brokerzeit GMT+2/+3) | Σ Stop-Risiko je Session |
| D5 Gemeinsame Tail-Tage | Kalendertage, an denen ≥K Sleeves gleichzeitig im schlechtesten 5%-Tages-P/L-Dezil liegen (aus OOS-Tages-P/L-Matrix) | `joint_tail_day_count`, `worst_joint_day_loss` |

Ergänzende Messgröße (VaR-nah, Darwinex-kompatibel): **portfolio-historischer
95%-Tages-VaR** aus der summierten OOS-Tages-P/L-Matrix der Kandidaten — als
*Sichtbarkeits*-Zahl neben der Stop-Risk-Summe, nicht als Ersatz.

## 3 · Vorgeschlagene Caps (PROPOSED — Ratifikation = OWNER)

Bezugsgröße: kontoweites Stop-Risk-Budget `B` (aktuell 2,5 % je SP-C2).

- D1 Symbol: ≤ 40 % von B je Symbol.
- D2 Assetklasse: ≤ 60 % von B je Klasse.
- D3 Familie: ≤ 50 % von B je Familien-Fingerprint.
- D4 Session: ≤ 70 % von B je Session (weich: WARN ab 60 %).
- D5 Joint-Tail: `worst_joint_day_loss` (historisch, OOS) ≤ 80 % des
  5%-Tageslimits des Ziel-Venues; K = ceil(n/3).

Caps sind **Builder-Abweisungs­kriterien** (Kandidat kommt nicht ins Buch) und
**Report-Ampeln** (bestehendes Buch: WARN/BREACH sichtbar). Sie ändern NIE
selbsttätig ein Live-Gewicht — jede Konsequenz am lebenden Buch ist OWNER-Zeremonie.

## 4 · Integrationspunkte (Implementierung Codex)

1. `portfolio_builder` (build_book_*): Cap-Prüfung als fail-closed Filterstufe
   nach der Orthogonalitätsprüfung; Abweisungsgrund maschinenlesbar
   (`concentration_reject: {dim, value, cap}`).
2. Report/Cockpit: Konzentrations-Panel je Buch (5 Dimensionen + VaR-Zahl +
   Joint-Tail-Tage mit Datumsliste); Datenquelle ausschließlich Evidenz-Dateien.
3. Kein neuer Datenerzeuger: alles aus vorhandenen aggregate.json/Streams;
   fehlt eine OOS-Tages-P/L-Reihe → Kandidat `UNKNOWN` = nicht buchfähig
   (fail-closed, kein Default).

## 5 · Testplan

- Fixture-Bücher: (a) 3 Sleeves gleiches Symbol → D1-Reject; (b) 4 Familien-
  Klone → D3-Reject; (c) konstruierte Tages-P/L-Matrix mit 3 gemeinsamen
  Tail-Tagen → D5-Zahlen exakt; (d) fehlende Reihe → UNKNOWN-fail-closed;
  (e) sauberes 4-Sleeve-Buch → PASS mit Panel-Werten.
- Golden-Case: das Blueprint-4-Sleeve-Set (F2/F3-Evidenz) als Realdaten-Fixture.

## 6 · ROT-Grenze (explizit)

Cap-Zahlen aus §3 sind Vorschläge; Ratifikation über `OWNER-DEC-STAT-CONTRACT`
oder separaten Entscheid. Anwendung auf das lebende DXZ-Buch (Gewichte, Entnahmen)
ist ausnahmslos OWNER. Der Builder-Einsatz betrifft nur zukünftige Buch-Vorlagen.
