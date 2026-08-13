# Pattern-Permission-Filter — Bau, Zensus, Optimierung

## Context

OWNER-Direktive 2026-08-13: den Pattern-Filter aus der eigenen QuantRangePRO-Linie
vollständig in QuantMechanica V5 bauen — alle Muster außer Kill-Listen-Material,
getrennt nach Buy/Sell, jedes einzeln gemessen, ohne Abkürzungen.

**Ausgangslage (verifiziert, nicht angenommen):** Es existiert bis heute **kein Zeile
Code** dafür. `qm_pattern_profile` kommt im Repo nirgends vor. Gestern gebaut wurde die
Optimierungs-*Strecke* (Q14 Admission → Q15 Freeze → Q16 Head-to-Head → Dual-Buch),
nicht der Filter und kein „EA Framework 2.0". Was existiert: ein Design (Survivor-
Programm §5) und eine Portabilitäts-Analyse mit fertigem API-Entwurf
(`docs/research/CODEX_UNGER_REFERENCE_PORTABILITY_2026-08-12.md:180-292`).

**Warum es sich lohnt (harte Evidenz aus OWNERs eigenem A/B, gleiche Parameter,
5,5 Jahre AUDUSD):** Filter AN → PF 1,36 / MaxDD 9,78 %; Filter AUS → PF 1,26 /
MaxDD **20,66 %**. Der Drawdown halbiert sich. Das ist der stärkste einzelne
Hebel-Beleg, den wir für einen Filter haben — er stammt aber aus OWNERs Tester,
nicht aus unserer Pipeline, und muss bei uns von Null verdient werden.

**Ergebnis am Ende:** ein produktionsreifer, fail-closed, closed-bar Pattern-
Permission-Filter als opt-in Include; ein vollständiger Einzelprädikat-Zensus
(jedes Muster × Buy/Sell einzeln gemessen, jede Messung im Trial-Ledger); daraus
maximal 1–2 kompilierte Profile pro Sleeve, die als Challenger gegen die
No-Change-Kontrolle auf versiegelten OOS-Fenstern gewinnen müssen.

---

## Architektur-Entscheidungen (aus der Framework-Erhebung)

### E1 — Einhängepunkt: NICHT `Strategy_NoTradeFilter`

Der Hook `Strategy_NoTradeFilter()` (`framework/templates/EA_Skeleton.mq5:89-93`,
Aufruf `:189-190`) läuft **pro Tick und blockiert den ganzen Tick** — inklusive
`Strategy_ManageOpenPosition()` und `Strategy_ExitSignal()`. Ein Pattern-Veto dort
würde bei „heute kein Long erlaubt" auch das Management offener Positionen
abwürgen. Das wäre ein stiller Risiko-Defekt.

**Entscheidung:** Das Veto sitzt **nach `Strategy_EntrySignal(req)` und vor
`QM_TM_OpenPosition(req, …)`** (`EA_Skeleton.mq5:235-242`), also hinter dem
Closed-Bar-Gate `QM_IsNewBar()` (`:228-229`). Exits, Management, Kill-Switch und
News-Gate bleiben unangetastet und behalten Vorrang.

### E2 — Blast Radius: neuer opt-in Include, **kein** `QM_Common`

`QM_Common.mqh` wird von jedem EA inkludiert (`V5_FRAMEWORK_DESIGN.md:328-336`) —
eine Änderung dort erzwingt Flotten-Recompile und Hash-Churn über alle Sleeves,
plus OFF/ON-Fenster. **Entscheidung:** neues `framework/include/QM/QM_PatternPermission.mqh`
nach dem Muster der schlafenden `QM_FilterVolatility.mqh` / `QM_FilterRegime.mqh`
(existieren, sind no-ML, werden heute nur von QM5_10788 direkt genutzt).
Kein Include in `QM_Common`. Bestehende Live-Binaries bleiben byte-identisch.

### E3 — Profile statt freier Slots

Keine 10 freien Slots × N Muster × 2 Richtungen (der Suchraum der Referenz ist
>10²⁰ und genau die Methodik, unter der OWNERs eigene Rewrite regressierte).
Stattdessen: `.set` deklariert `qm_filter_pattern_enabled` + `qm_pattern_profile=<NAME>`;
das Profil ist **im Code kompiliert und karten-deklariert** (Referenz-TF,
closed_shift, Buy-/Sell-Prädikate, Whitelist/Blacklist, Missing-Data-Verhalten).
Neue Inputs unter neuer Input-Gruppe `Filters` — zulässig, die fünf Pflichtgruppen
(`build_check.ps1:825-843`) bleiben unberührt; `gen_setfile.ps1:278` nimmt
`strategy_*`-Inputs automatisch auf. **Kein Registry- oder Schema-Change nötig.**

### E4 — Fail-closed und repaint-frei

Referenz-Defekte, die NICHT portiert werden: `bar[0]`-Auswertung (repaintet) und
Fail-open (`PatternFilter.mqh:250-259` lässt bei ungültigem Zustand beide
Richtungen offen). Unsere Regel: `closed_shift >= 1` (Shift 0 wird bei Init
abgelehnt), `valid=false` ⇒ **beide Richtungen blockiert**, Cache-Key
`(symbol, reference_tf, reference_bar_time, profile)` ⇒ Neustart und Tick-Kadenz
können eine Entscheidung nicht ändern.

### E5 — API (aus der Portabilitäts-Analyse übernommen)

```mql5
struct QM_PermissionResult { bool allow_buy; bool allow_sell; bool valid;
                             datetime reference_bar_time; string reason; };
QM_PermissionResult QM_PatternPermissionEvaluate(
   const string symbol, const ENUM_TIMEFRAMES reference_tf,
   const int closed_shift, const QM_PatternProfile profile);
```
Rein funktional über gelieferte geschlossene OHLC(V)/Kalender-Daten; fasst
Stops, Exits, Risiko, Kill-Switch, News oder Positionen nie an.

---

## Pattern-Umfang — die echte Zahl ist 101, nicht 60

Vollständiger Katalog aller IDs gegen den *implementierten Code* gelesen
(`Patterns.mqh`, 1304 Zeilen). Der Enum reicht bis **100**, also 101 Einträge.

| Eimer | Bedeutung | Anzahl |
|---|---|---:|
| **A** | portabel: reines OHLC + Kalender, closed-bar rechenbar auf .DWX | **72** |
| **B** | braucht Tick-Volumen (Broker-Tickzahl, kein echtes Volumen) | 1 |
| **C** | Daten fehlen (Optionen/OI/Cross-Symbol/echtes Volumen) | **0** |
| **D** | Kill-Liste (SMC/ICT/FVG/OrderBlock/BOS/ChoCh, Wyckoff, Hurst, HMM-Tag) | 25 |
| **E** | degeneriert (DISABLED / ALWAYS_ALLOW / ALWAYS_BLOCK) | 3 |

**Drei Befunde, die den Bau prägen:**

1. **Kein einziges Muster braucht Daten, die uns fehlen (C=0).** Die drei
   „gefährlich" klingenden Namen sind Fehlbezeichnungen: ID 97 „Correlation
   Breakdown" rechnet in Wahrheit ein Ein-Symbol-ATR-Verhältnis (Quasi-Dublette von
   83); ID 99 „Options Expiry" liest nur den Kalender (3.-Freitag-Test); ID 98
   „Volume Climax" nutzt Tick-Zahlen. Nichts liest Optionen, Open Interest oder ein
   zweites Symbol.
2. **Der Repaint-Defekt ist systemisch, nicht punktuell.** *Alle* Preis-Muster (3–98)
   lesen `bar[0]`, die noch offene Tagesbar (`PatternFilter.mqh:240,263`), während der
   Filter untertägig läuft. Unsere Portierung indiziert durchgängig ab `bar[1]`.
3. **Zwei Muster (90, 91) feuern in der Referenz nie** — sie brauchen 100 Bars,
   `lookbackBars` ist 22. Wir implementieren sie mit korrektem Lookback.

**Umfang für den Bau: 77 Prädikate** — OWNER-Entscheid 2026-08-13:
- 72 aus Eimer A,
- **+4 reklassifiziert** (77/78/80/81): in der Referenz `(HMM)`-getaggt, im Code aber
  triviales Zählen bullischer/bärischer Bars von 10. Substanz schlägt Etikett; sie
  werden **ehrlich umbenannt** (Bar-Count-Trendstärke, kein Modell) und die
  Reklassifizierung steht im Katalog,
- **+1 markiert** (98, Tick-Volumen): DWX-Tickzahl ist ein Proxy für echtes Volumen —
  wird implementiert, aber in Karte und Profil ausdrücklich als Proxy gekennzeichnet.

**Nicht implementiert: 21 Kill-Liste** (SMC/ICT/FVG/OrderBlock/BOS/ChoCh 61–76,
Wyckoff 85/86, Hurst 95/96, Fake-Korrelation 97) **+ 3 Steuerwerte.**
Die Liste steht vollständig im Katalog-Anhang, damit für immer nachvollziehbar ist,
was warum draußen blieb.

---

## Zensus-Design — und drei Bruchstellen im bestehenden Track

Der Q14→Q16-Track ist auf **eine geordnete numerische Achse pro Karte** verdrahtet.
Ein Zensus über K unsortierte benannte Prädikate passt nicht ohne Vertragserweiterung.
Drei Stellen, ehrlich benannt:

### B1 — Kategoriale Parameterfläche (mittel)
`q14_opt_admission.py:396-401` castet jeden Kandidaten durch `float()`; benannte
Prädikate sterben dort. `:404-405` erzwingt genau **eine** Achse. Die Schemas
(`opt_card.v1`, `opt_trial_ledger.v1`) tragen benannte Trials bereits — nur der
Python-Validator nicht. **Vorbild existiert:** der LOCKED_PORT-Carrier-Pfad
(`q14:407-415`) emittiert genau die gewünschte Form (`{trial_id, carrier}`, keine
Bounds). → neuer Lever `PREDICATE_ABLATION` + kategorialer Zweig in `_surface`,
modelliert am Carrier-Pfad. Lever-Enum auch in `opt_card.v1.schema.json:94-101`.

### B2 — Q15-Plateau-Regel (die größte Änderung)
`q15_freeze_check.py:507-544` verlangt: gewählter Wert auf dem 5%-Plateau **und**
ein *numerisch benachbarter* Kandidat ebenfalls. Bei unsortierten Prädikaten gibt es
keine Nachbarschaft — die Regel würde einen validen Gewinner fälschlich ablehnen.
→ **kategorialer Selektionspfad**, der den Ordnungs-Zweig *umgeht* statt ihn
aufzuweichen, mit eigener, ebenso strenger Ersatzregel:
**Robustheits-Kriterium statt Nachbarschaft** — der gewählte Prädikat-Gewinner muss
(a) auf DEV die Metrik schlagen **und** (b) in ≥2 von 3 disjunkten DEV-Teilfenstern
(Zeitdrittel) vorne bleiben. Das ersetzt „Nachbar-Plateau" durch „zeitliche
Stabilität" — dieselbe Absicht (kein Messer-Kanten-Gewinner), passende Geometrie.
Ebenso: `q03_plateau_runner.py:5-8` trägt dieselbe Ordnungsannahme → der Zensus
braucht einen eigenen Trial-Generator, nicht den Q03-Runner.

### B3 — ★ Trial-Ledger deflationiert die Statistik NICHT (kritisch)
DL-084 behauptet, jeder Trial fließe in Q07-DSR / Q08-PBO. **Tut er heute nicht.**
`q08_davey/sub_8_2_dsr_mc_fdr.py:34` hat `N_CANDIDATE_STRATEGIES = 369` **hartkodiert**;
`sub_8_7_pbo.py:100-113` zieht `n_configs` aus einer separat erzeugten `scores.csv`.
`declared_trial_count` kommt in `q08_davey/*` **nirgends** vor — Q16 prüft nur
Zähl-Konsistenz. Dazu ist `sharpe_std = 1.0` ein Platzhalter (`sub_8_2:135`, TODO :38-40).
**Konsequenz:** Ein Zensus mit K×2 Trials pro Sleeve würde unter unveränderter
Deflation systematisch Fehlfunde produzieren — genau der Overfitting-Unfall, den das
ganze Design vermeiden soll. → **Die Verdrahtung ist Teil dieses Plans und Vorbedingung
für den ersten Zensus-Lauf.** Kein Zensus vor B3.

### B4 — Fehlende Emitter
`dev_sweep.json` und das `qm.q16-lineage/v1`-Artefakt haben **keinen Erzeuger** —
heute Handarbeit. Bei 9 Paaren × K×2 Trials unhaltbar → deterministischer Generator.

---

## Phasen

**Schritt 0 — Codex-Review dieses Plans (OWNER-Auftrag)**
Vor dem ersten Codezeile: Plan als ops_issue an Codex zur unabhängigen Kritik,
Schwerpunkt auf (a) B3-Deflations-Verdrahtung — ist meine Diagnose korrekt und ist
die vorgeschlagene Reparatur die richtige?, (b) das Ersatzkriterium für die
Plateau-Regel, (c) Blast-Radius der Include-Entscheidung, (d) übersehene
Fail-closed-Lücken. Feedback wird eingearbeitet, *dann* P0.

**P0 — Vertrags-Reparatur (vor allem anderen)**
B3 zuerst: `declared_trial_count` in DSR/PBO verdrahten, `N_CANDIDATE_STRATEGIES`
durch die tatsächliche family-wise Zahl ersetzen, `sharpe_std`-Platzhalter adressieren
oder explizit als Limitation dokumentieren. Regressionstests: bestehende Q08-Ergebnisse
dürfen sich bei declared=0/None nicht ändern (Rückwärtskompatibilität), bei declared=N
muss die Deflation nachweisbar strenger werden.

**P1 — Filter-Include + Prädikate**
`framework/include/QM/QM_PatternPermission.mqh` neu (opt-in, **nicht** in `QM_Common`).
Alle K Prädikate aus Eimer A/B, jedes als reine Funktion über geschlossene Bars,
`closed_shift>=1`, `valid`-Flag fail-closed, Cache nach
`(symbol, tf, reference_bar_time, profile)`. Profil-Struktur mit getrennten
Buy-/Sell-Prädikatlisten + Whitelist/Blacklist-Modus.
**Unit-Tests pro Prädikat** gegen handgerechnete OHLC-Fixtures (jede Regel einzeln,
Grenzfälle, Missing-Data ⇒ invalid). Das ist der „keine Abkürzung"-Kern: K Prädikate,
K Testfälle-Sets, kein Sammel-Test.

**P2 — Zensus-Maschinerie**
Neues `opt_program_census.v1.json` (eigene Datei, Q14 nimmt `--config`), Lever
`PREDICATE_ABLATION`, kategorialer `_surface`-Zweig, kategorialer Q15-Pfad mit dem
Teilfenster-Robustheitskriterium, DEV-Sweep- und Lineage-Emitter.
Trial-Cap beachten: `q14:423` deckelt bei 64/Karte → K×2 Trials werden in Karten
gebündelt (z. B. je Richtung eine Karte), Bündelung explizit dokumentiert.

**P3 — Zensus über die volle Kohorte (OWNER-Entscheid)**
Alle **9 Q10-PASS-Paare** der eingefrorenen Kohorte, **alle 77 Prädikate × Buy und
Sell einzeln gemessen**:

| Größe | Rechnung | Wert |
|---|---|---:|
| Trials je Sleeve | 77 × 2 Richtungen | 154 |
| Zellen gesamt | 154 × 9 Paare | 1.386 |
| Backtests | × 2 Runs (Determinismus-Pflicht `q03:531`) | **2.772** |
| Flottenzeit | ~10 min/Run ÷ 10 Worker | **≈ 46 h** |

**Konsequenz, die OWNER kennen muss:** Das belegt die Fabrik rund **zwei Tage**.
Parallel warten 867 Q02-Läufe und die Challenger-Welle. Deshalb **paced, parent-seriell**:
ein Sleeve nach dem anderen, zwischen den Wellen atmet die normale Queue. Kein
Eingriff in Worker-Konfiguration, keine Drosselung von Backtests — nur Reihenfolge.
DEV/IS-Fenster strikt vor allen OOS-Fenstern; jede Messung im Ledger; Fails publiziert.
Caps: eigenes Programm-File; bei Trial-Cap 64/Karte (`q14:423`) werden die 154 Trials
je Sleeve in Karten gebündelt (Bündelung explizit dokumentiert, Caps entsprechend gesetzt).

**Exakter Beschleuniger, den wir uns verdienen statt ihn anzunehmen:** Je Sleeve läuft
zusätzlich *ein* instrumentierter Backtest, der pro Entry-Bar den vollen Prädikat-Vektor
mitloggt; daraus ist jede Ablation offline rekonstruierbar. Da `RISK_FIXED` gilt, gibt
es keine Equity-Rückkopplung — die Rekonstruktion ist **exakt**, außer bei
Zustandskopplung (13213 storniert die Gegenorder beim Trigger, `:347`: blockiert man den
Buy, überlebt der Sell anders). Vorgehen: Der erste Sleeve wird **vollständig doppelt**
bestimmt (154 echte Backtests *und* Log-Rekonstruktion) und beides verglichen. Ist die
Rekonstruktion für einen EA-Typ nachweisbar exakt, darf sie dort die Backtests ersetzen —
das ist dann keine Abkürzung, sondern dieselbe Messung billiger. Ist sie es nicht,
läuft alles voll durch. Der Vergleich selbst wird als Evidenz veröffentlicht.

**P4 — Promotion**
Max. 1–2 Profile pro Sleeve als **neue EA-Identität** (Challenger, 21xxx-Bereich),
Standard-Kaskade Q02→Q10, dann Q16 sealed Head-to-Head gegen No-Change-Kontrolle.
Kein Live-Kontakt, keine Buch-Änderung ohne Q16-Verdikt und OWNER-Zeremonie.

---

## Verifikation

- **P0:** pytest auf `q08_davey` — Rückwärtskompatibilität (declared fehlt ⇒ identische
  Ergebnisse) und Wirksamkeit (declared=N ⇒ strengere Deflation), plus ein
  Ende-zu-Ende-Lauf auf einem bestehenden Q08-Fall mit Vorher/Nachher-Vergleich.
- **P1:** pytest/MQL-Fixture-Suite pro Prädikat; strict compile 0 Fehler/0 Warnungen;
  `build_check.ps1` PASS; Nachweis, dass kein bestehendes `.ex5` sich ändert
  (Blob-Hash-Vergleich vor/nach — Beweis für „kein Flotten-Recompile").
- **P2:** Q14-Dry-Run erzeugt deterministisch identische Karten (zweifacher Lauf,
  SHA-Vergleich); Q15-Dry-Run auf einem Fixture-Challenger PASS; alle Fail-closed-Fälle
  getestet (unsortierte Fläche im numerischen Pfad ⇒ Fehler, fehlendes Teilfenster
  ⇒ Ablehnung).
- **P3:** Ledger-Vollständigkeit (declared == observed == K×2), DEV-Fenster-Dichtheit
  (kein OOS-Kontakt), Reproduzierbarkeit zweier identischer Läufe.
- **P4:** Q16 verlangt bereits sealed windows + No-Change-Kontrolle + Marginalprüfung —
  unverändert übernommen.

Alle Läufe read-only bis zum expliziten `--apply`; kein Terminal manuell gestartet;
T_Live/FTMO/AutoTrading unberührt; Commits mit expliziten Pathspecs auf
`agents/board-advisor`, main bleibt Claude+OWNER.
