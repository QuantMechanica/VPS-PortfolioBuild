# DL-066 — Q08.2 DSR: First-Entry-Trivial-Pass + evidenzbasierte Kohorten-Kalibrierung

**Date:** 2026-06-01
**Status:** Decided (OWNER + Claude) — semantischer Fix ausgeliefert (`e1efa5743` auf main); Kohorten-Kalibrierung als bindende Regel für den späteren Cohort-Modus
**Supersedes:** none
**Related:** DL-064 (Portfolio-Construction-Layer — die Peer-Kohorte, gegen die die DSR-Deflation rechnet, ist exakt das Buch, das R-064-3 baut), `project_qm_q08_subgate_miswired_2026-06-01` (Diagnose-Verlauf), `framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py`, CLAUDE.md Hard Rule „keine erfundenen Werte / Evidenz über Behauptungen"

## Kontext

Q08 (Davey, 10 Sub-Gates) ist die Wand zum Portfolio-Buch — `portfolio_candidates`
war leer, weil **0 EAs Q08 bestanden**. Drei aufeinanderfolgende Ursachen wurden
an diesem Tag gefunden und gefixt; die letzte ist Gegenstand dieser DL.

1. `run_smoke.ps1` suchte den Real-Ticks-Marker nur im Log-Tail → False
   `NO_REAL_TICKS_MARKER` → INVALID (`f7c038d02`).
2. Sub-Gate-Semantik (Trivial-Pass als FAIL markiert, fehlende Inputs)
   (`3c2e8dc4b`).
3. **Diese DL:** Sub-Gate **8.2 (Deflated Sharpe Ratio) gab bei einem
   DSR-Tier-1-Fail `INVALID` zurück** und erwartete eine Batch-level-BH-FDR-
   Rescue-Pass im Aggregator. **Diese Kohorten-Pass wurde nie implementiert**
   (`aggregate.py` macht nur per-EA `run_all` + AND-combine). Folge: jede
   First-Mover-EA hing **permanent auf INVALID** → Aggregat-Verdikt INVALID
   (Any-INVALID-Präzedenz in `_aggregate_verdict`). Das war kein Strategie-
   Schwäche-Problem, sondern ein Dead-End.

**Evidenz (Laufzeit):** QM5_10513 XAUUSD.DWX, `aggregate.json` —
n_trades=76, Sub-Gate 8.2 `status=INVALID, p=1.0000, tier=watchlist_pending_fdr`.

**Zweite, tieferliegende Schicht:** Selbst mit gefixter Semantik ist die
Deflations-Schwelle mit den heutigen **Platzhaltern** (`sharpe_std=1.0`,
`N_CANDIDATE_STRATEGIES=369`) bei E[max] ≈ √(2·ln N) ≈ **3,36 annualisierter
Sharpe** — für jede realistische Strategie unpassierbar. Zusätzlich kann der
Varianzterm der Bailey-/López-de-Prado-Formel negativ werden, wenn ein
*annualisierter* SR mit einem *Tages*-`n_obs` kombiniert wird (Units-Mismatch).
Eine echte Kalibrierung verlangt eine empirische Candidate-Sharpe-Verteilung —
die es ohne Kohorte noch nicht gibt (Henne-Ei).

## Entscheidung

**Die DSR-Deflation ist eine Kohorten-/Multiple-Testing-Korrektur. Ohne Peer-
Kohorte gibt es keinen Selection-Bias zu deflationieren — also verhält sich 8.2
im First-Entry-Fall wie 8.1 (Korrelation) und 8.3 (Tail-Dependence): es macht
einen Trivial-Pass „pending cohort". Ein berechnetes statistisches Ergebnis wird
NIE mehr als INVALID zurückgegeben — INVALID ist allein für Infrastruktur-/
Datenlücken reserviert. Der Cohort-Modus vergibt erst dann echte FAILs, wenn ein
evidenzbasiertes `sharpe_std` (und N) aus der realen Farm-Verteilung vorliegt —
kein erfundener Platzhalter-Wert.**

## Bindende Regeln

### R-066-1 — INVALID nur für Infra-/Datenlücken, nie für statistische Ergebnisse
In allen Q08-Sub-Gates trennt `INVALID` Infrastruktur-Defekte (re-runnable) von
echten Verdicts. Ein berechnetes statistisches Resultat (PASS/FAIL) darf nie als
INVALID maskiert werden. In 8.2 bleibt einzig `<60 Tagesreturns` → INVALID
(echte Datenlücke).

### R-066-2 — First-Entry / leere Kohorte → Trivial-Pass pending cohort
Bei `portfolio_size < MIN_COHORT_PEERS` (heute 1) gibt 8.2 PASS mit
`tier=standalone_pending_cohort` zurück, konsistent mit 8.1/8.3. Begründung:
Ohne Peer-Kohorte existiert die Multiple-Testing-Selektion nicht, gegen die
deflationiert wird. Die übrigen 9 Sub-Gates (Saison, PBO, Edge-Decay, Runs-Test,
Regime-Crisis, Chopping-Block, Neighborhood, Korrelation, Tail) tragen das Gate
weiter — Q08 behält seine Zähne.

### R-066-3 — Cohort-Modus braucht evidenzbasiertes `sharpe_std` (kein erfundener Wert)
Sobald eine Kohorte existiert, läuft die DSR-Deflation. Vor dem ersten echten
Cohort-Mode-FAIL MUSS `sharpe_std` aus der **realen Candidate-Sharpe-Verteilung**
der Farm geschätzt werden (und N aus der tatsächlichen Trial-Zahl) — nicht aus
dem 1.0/369-Platzhalter (Hard Rule: keine erfundenen Werte). Teil der Schätzung
ist ein **Units-Check** (annualisierter SR vs. Tages-`n_obs` im Varianzterm).
Die Rohdaten liegen bereits vor: die `TRADE_CLOSED`-JSONL-Streams je EA unter
`Common\Files\QM\q08_trades\<ea>_<sym>.jsonl` — dieselbe Quelle, die der
Korrelations-Aggregator aus DL-064 R-064-3.1 nutzt. Diese Regel hängt damit
direkt an DL-064.

### R-066-4 — Tier-1-Fail ist FAIL, mit optionalem späteren FDR-Rescue
Im Cohort-Modus ist ein DSR-Tier-1-Fail ein **FAIL** (echtes Verdikt,
`tier=fdr_rescue_eligible`), kein INVALID-Dead-End. Wird später eine Batch-level-
BH-FDR-Pass über die Kohorte implementiert, darf sie FAIL→PASS überschreiben
(Tier-2-Watchlist-Rescue). Bis dahin gilt das standalone FAIL.

## Risiken / Blocker

- **Trivial-Pass ist kein Freifahrtschein.** Er funktioniert nur, weil Q08 über
  10 Sub-Gates AND-kombiniert; 8.2 hört auf zu blockieren, die anderen 9 prüfen
  weiter. Würde man mehrere Sub-Gates gleichzeitig trivial-passen lassen,
  entstünde ein Loch — diese DL betrifft ausschließlich 8.2.
- **Die Kalibrierung (R-066-3) ist die eigentliche Substanz** und bleibt offen,
  bis eine Kohorte existiert. Ein zu früh gesetztes `sharpe_std` würde entweder
  alles fälschlich durchlassen oder (wie der Platzhalter) alles fälschlich
  FAILen. Lieber Trivial-Pass + die anderen 9 Gates als ein erfundener Wert.
- **Henne-Ei mit DL-064:** die Kohorte entsteht erst, wenn EAs Q08 passieren und
  ins Buch fließen. R-066-2 bricht genau diesen Deadlock auf (First-Mover kommen
  durch), DL-064 baut das Buch, dann liefert die Farm die Verteilung für R-066-3.

## Abgelehnte Alternativen

### Alt. 1 — INVALID beibehalten, auf Batch-FDR-Pass warten
Abgelehnt. Die Batch-FDR-Pass existiert nicht und ihr Bau verlangt ohnehin eine
Kohorte. INVALID-Beibehaltung hält das Gate permanent tot — eine nicht-
funktionale Wand ist schlimmer als ein per-EA-Verdikt.

### Alt. 2 — Single-EAs hart durchwinken (Auto-PASS auf 8.2 generell)
Abgelehnt. Würde 8.2 dauerhaft entwerten statt nur den nicht-anwendbaren First-
Entry-Fall zu adressieren. R-066-2 ist eng auf `portfolio_size < MIN_COHORT_PEERS`
begrenzt; sobald eine Kohorte existiert, greift wieder die echte Deflation.

### Alt. 3 — `sharpe_std` jetzt „konservativ" auf einen plausiblen Wert setzen
Abgelehnt — Hard-Rule-Verstoß (erfundener Wert ohne Evidenz). Der Wert MUSS aus
der realen Verteilung geschätzt werden (R-066-3), sonst ist jedes Cohort-Mode-
Verdikt Artefakt.

## Implementierung

1. ✅ **Semantischer Fix ausgeliefert** (`e1efa5743`, auf main): R-066-1, R-066-2,
   R-066-4 in `sub_8_2_dsr_mc_fdr.py`; `MIN_COHORT_PEERS`-Konstante;
   `TODO(calibration)` am Platzhalter verankert. +2 Tests (First-Entry-Trivial-
   Pass; Cohort-Tier-1-Fail = FAIL nicht INVALID); 11/11 Q08-Sub-Gate-Tests grün.
2. ☐ **R-066-3 (Kalibrierung)** — offen, an DL-064 R-064-3.1 gekoppelt: nach
   Entstehen der ersten Kohorte `sharpe_std`/N aus den `q08_trades`-Streams
   schätzen + Units-Check; dann Cohort-Modus scharf schalten. Eigenes Work-Item,
   ausgelöst durch das Erscheinen der ersten `portfolio_candidates`.
3. ☐ **R-066-4 Batch-FDR-Rescue** — optional, nach R-066-3; BH-FDR über die
   Kohorten-p-Values als FAIL→PASS-Override.
