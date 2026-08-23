# Pipeline Operations Workflow — Q-Series (v4, linear)

**Status:** Staging-Entwurf (v4)  
**As of:** 2026-08-23  
**Kanonische Ziel-Topologie:** `tools/strategy_farm/config/gate_manifest.v4.json` (linear, drei
Makrophasen). Bis zur OWNER-Ratifikation bleibt der aktive Runtime-Vertrag
`gate_manifest.v3.json`.  
**Detail:** [[Pipeline Overview]] · **Diff:** [[Gate Manifest v4 Diff]] · **Direktive:**
[[Pipeline Rebaseline Directive 2026-08-23]]

## Zweck

Diese Seite beschreibt die Übergaben zwischen Research, Development, Pipeline und OWNER.
Gate-Verdicts stammen aus gebundener Evidenz; Chat, Tickets und Dashboards sind keine
Ersatzbeweise.

## Gesamtfluss (streng linear, drei Makrophasen)

```text
Makrophase 1 — Strategie beweist sich
Source Approval
  → Q00 Research Intake / Card Authorization                 OWNER
  → Q01 Build & Spec                                        Development
  → Q02 Baseline Screening                                  Pipeline
  → Q03 Parameter Sweep                                     Pipeline
  → Q04 Walk-Forward + Commission                           Pipeline
  → Q05 Gross Full-History Robustness → Q06 Stress HARSH    Pipeline
  → Q07 Multi-Seed → Q08 Davey Statistical Validation       Pipeline

Makrophase 2 — Strategie wird optimiert / requalifiziert
  → Q09 Baseline Full Run (pre-news)                        Pipeline
  → Q10 News Impact + FTMO Recommendation                   Pipeline
  → Q11 Incumbent Full-History Confirmation                 Pipeline
  → Q12 Pattern Filter Selection (DL-089, Cap 3/Richtung)   Pipeline
  → Q13 Parameter Optimization & Freeze (Challenger Q02→Q11) Development
  → Q14 Best-Settings Head-to-Head + Holdout   TERMINAL (next=null)  Pipeline

── Buch-Trigger (fail-closed): ≥25 qualifizierte Kandidaten UND OWNER-Buchauftrag ──

Makrophase 3 — Strategie wird zum Buch bewertet
  → Q15 Final Portfolio Construction                        OWNER
  → Q16 Operational Readiness                               OWNER
  → Q17 Live Burn-In on DXZ Live                            OWNER
```

Der Pfad ist streng monoton: jede `next`-Kante ist `null` oder der unmittelbare Nachfolger.
Die v3-Nicht-Linearitäten (Q10A vor Q09, Rücksprung Q16→Q11) sind entfernt.

## Gemeinsamer Übergabevertrag

Jeder Übergang nennt mindestens:

```yaml
ea_id:
symbol_id:
gate_id:
gate_contract_version:
card_hash:
build_hash:
setfile_hash:
work_item_id:
evidence_paths: []
report_hashes: []
execution_status:
economic_verdict:
next_gate:
```

Fehlt eine erforderliche Bindung, lautet das Ergebnis `INFRA`/`INVALID`, niemals
wirtschaftliches `FAIL` oder `PASS`.

## Q00 — Research Intake

**Vor:** OWNER-freigegebene Quelle mit durablem Approval-Record.  
**Aktion:** Strategie mechanisch extrahieren, R1–R4 prüfen, Card versionieren.  
**Nach:** Card ist `APPROVED`, `REJECTED` oder `PENDING`; nur `APPROVED` darf Q01 starten.

Pflicht: Source-Provenance, Economic Thesis, Failure Hypothesis, Entry/Exit/Risk,
Datenverfügbarkeit, No-ML und eindeutige Card-Version.

## Q01 — Build & Spec

**Vor:** autorisierte Card plus deterministisch reservierte EA-ID und Magic-Zeilen.  
**Aktion:** Framework-EA bauen, kompilieren, Build-Checks und sinnvollen Smoke durchführen.  
**Nach:** `.mq5`, `.ex5`, SPEC/Card-Bindung, Sets, Compile- und Smoke-Evidenz liegen vor.

Zero Trades oder fehlender Report werden zuerst nach [[../05 Skills/qm-zero-trades-recovery]]
als Setup-/Implementierungsproblem klassifiziert. Ein Smoke ersetzt Q02 nicht.

## Q02 — Baseline Screening

**Vor:** Q01-konformer Build und Symbol-/Setfile-Matrix.  
**Aktion:** IS-only Baselines auf T1–T10, Model 4, Fixed Risk, pro Symbol.  
**Nach:** jedes Symbol besitzt ein gebundenes Verdict; nur PASS-Symbole gehen nach Q03.

NO_REPORT, fehlende Historie, DST-/Symbolfehler und ungültige Setfiles sind
Infrastrukturklassen. Sie dürfen die Strategie nicht wirtschaftlich töten. Ein sauber
gemessenes Q02-FAIL bleibt terminal (Direktive §1).

## Q03 — Parameter Sweep

**Vor:** Q02-PASS-Symbole; OOS bleibt versiegelt.  
**Aktion:** vorregistriertes Grid im IS-Fenster; Plateau und Nachbarschaft bewerten.  
**Nach:** Plateau-Median statt Einzeloptimum wird eingefroren und an Q04 übergeben.

## Q04 — Walk-Forward + Commission

**Vor:** eingefrorene Q03-Parameter und sauberer Embargo-Nachweis.  
**Aktion:** drei verankerte OOS-Folds mit realistischem Kostenvertrag.  
**Nach:** aggregiertes Verdict plus alle Fold-Reports; unzulässiges OOS-Lesen ist Hard Fail.

## Q05 bis Q08 — robuste Standardkaskade (Makrophase 1 Abschluss)

| Gate (v4) | Aufgabe | Wesentliche Evidenz |
|---|---|---|
| Q05 | Gross Full-History Robustness | reproduzierbarer Vollhistorienlauf auf Q03-Plateau-Median, GROSS |
| Q06 | Stress HARSH | geseedete 10%-Trade-Rejection (einzige Stress-Dimension) |
| Q07 | Multi-Seed | vollständige Seed-Matrix und Varianz (2-Achsen-Regel) |
| Q08 | Davey Statistical Validation | alle 11 Subgates und Trial-Budget → eingefrorene, target-neutrale Baseline |

## Q09 bis Q14 — Optimierung / Requalifikation (Makrophase 2)

| Gate (v4) | Aufgabe | Wesentliche Evidenz |
|---|---|---|
| Q09 | Baseline Full Run | pre-news Vollhistorien-Baseline je `(EA, Symbol)`; Referenz für Q14 |
| Q10 | News Impact + FTMO Recommendation | reale Mode-Reruns, Kalender-/Lineage-Bindung, `CONFIG_LOCKED` |
| Q11 | Incumbent Full-History Confirmation | abschließendes per-`(EA, Symbol)`-Confirmation-Verdict des Incumbent |
| Q12 | Pattern Filter Selection | vorregistrierte DL-089-Auswahl, Cap 3/Richtung, 0 Filter = Pass-Through |
| Q13 | Parameter Optimization & Freeze | DEV/IS-Sweep + Freeze; Challenger durchläuft Q02→Q11 |
| Q14 | Best-Settings Head-to-Head + Holdout | versiegelter Vergleich vs. Q09-Baseline UND Incumbent-Q11 — **terminal** |

Die Kaskade ist deterministisch und per Symbol. Q11 PASS bedeutet incumbent-confirmed; Q14
schließt die per-EA-Requalifikation ab (`KEEP_INCUMBENT` gültig). Weder ist ein automatischer
Buch-Eintritt noch eine Live-Freigabe impliziert.

## Q15 bis Q17 — OWNER-Gates (Makrophase 3, nur über Buch-Trigger)

### Buch-Trigger (fail-closed)

Der Eintritt in Q15 ist ausschließlich über den Guard erreichbar:
`(qualified_candidates ≥ 25) AND (owner_order_artifact vorhanden & verifiziert)`. Unter 25 wird
nur gemessen/vervollständigt; kein Probe-Buch. `Q14.next = null` — kein per-EA-Edge.

### Q15 Final Portfolio Construction

Claude berechnet auf Basis von Korrelation, Familien-/Symbolcaps, Marginalbeitrag,
Drawdown, Venue-Vertrag und gebundenem Book Manifest. DXZ und FTMO sind getrennte Lanes
(Storage `Q15_DXZ`/`Q15_FTMO`). Der analytische Buchlauf beginnt erst nach ausdrücklichem
OWNER-Auftrag.

### Q16 Operational Readiness

Compile, Binary-/Source-Gleichheit, Setfile, Symbolalias, Kosten, Risk, News, Restart,
Friday/Holiday-Exit, Logging und Deploy-Manifest werden fail-closed geprüft (11-Punkte-Checkliste).

### Q17 Live Burn-In

Nur OWNER-signiertes Manifest, `T_Live`, Min-Lot und festgelegte Beobachtungs-/Kill-Regeln.
Kein Agent schaltet AutoTrading. Erst ein OWNER-Verdict nach Burn-In erlaubt Full Live.

> **DL-089 (2026-08-21, `decisions/DL-089_live_book_full_chain_requalification.md`):** Für die
> Buch-Eignung des aktuellen Live-Buchs (21 EAs / 24 Sleeves) ist die Optimierungs-/
> Requalifikationsphase (Q12→Q14) **verpflichtend**, nicht optional — buch-fähig ist nur, wer die
> vollständige Kette (Rebuild → Q02…Q11 → Q12→Q13→Q14) trägt; Inkumbenz ist kein Beweis.
> Requalifikation läuft parallel auf rebuilten Fabrik-Binaries, die Live-Binaries handeln
> unberührt weiter.

## Closeout-Regel

Ein Gate wird erst geschlossen, wenn:

1. alle Pflichtartefakte existieren und ihre Hashes stimmen,
2. die Zähllogik pro Symbol/Run dokumentiert ist,
3. Setup-, Infra- und wirtschaftliche Verdicts getrennt sind,
4. der nächste Gate- oder Terminalzustand eindeutig ist,
5. OWNER-Fragen in der Entscheidungsschlange stehen,
6. Card/EA-Dossier und Lessons Learned synchronisiert wurden.

## Harte Abbrüche

| Ereignis | Behandlung |
|---|---|
| Magic-Kollision oder Registry-Drift | Hard Abort; keine manuelle Überschreibung |
| OOS vor Q04 eingesehen | Q04 Hard Fail / OWNER-Eskalation |
| Report fehlt oder ist leer | Infra-/Setup-Diagnose, kein Strategy-Fail |
| Card-, Build- oder Setfile-Hash widerspricht | Evidence invalid; neu binden und ausführen |
| `T_Live` ohne signiertes Manifest berührt | sofort stoppen und OWNER informieren |
| AutoTrading-Änderung durch Agent | verboten |
| Buchbau unter 25 Kandidaten oder ohne OWNER-Auftrag | fail-closed verweigert (Buch-Trigger) |
