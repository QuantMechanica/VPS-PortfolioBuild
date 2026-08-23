# Q15 — Final Portfolio Construction

> **Gate-Manifest v4 (linear, 3 Makrophasen) — Staging-Entwurf.** Aktiver Runtime-Vertrag
> bleibt bis zur OWNER-Ratifikation v3 (`gate_manifest.v3.json`, `default_manifest_switch=false`).
> Diese Seite spiegelt den v4-Vertrag `tools/strategy_farm/config/gate_manifest.v4.draft.json`.

| Feld | Wert |
|---|---|
| **v4 Gate-ID** | Q15 (Storage-Lanes v4: `Q15_DXZ` / `Q15_FTMO`) |
| **Makrophase** | 3 · Strategie wird zum Buch bewertet (Phasenkopf) |
| **v3-Herkunft** | Q11 — „Final Portfolio Construction" (Storage `Q11_DXZ` / `Q11_FTMO`) |
| **gate_contract_version** | v4 (historische v3-Zeilen behalten ihre Bedeutung über `gate_contract_version`) |
| **Eintritt** | **NUR über den fail-closed Buch-Trigger** — kein per-EA-`next`-Edge aus Q14 |
| **Navigation** | ← (Buch-Trigger, siehe unten) · → [[Q16 Operational Readiness]] |

**Herkunft:** v4 Q15 = v3 Q11 (Final Portfolio Construction), Buch-Kriterien und OWNER-Autorität
unverändert (ROT). Portfolio-Metriken werden auf Portfolio-Ebene neu berechnet, nicht per-EA
wiederverwendet.

## Buch-Trigger (Phase-3-Eintritt, fail-closed — OWNER-Direktive 2026-08-23)

Q15 ist **ausschließlich** über einen expliziten Guard erreichbar — nie über eine per-EA-Kante
(`Q14.next = null`). Der Guard **verweigert** (raises), er überspringt nicht still:

```
BOOK BUILD PERMITTED  ⇔  (qualified_candidates >= 25)  AND  (owner_order_artifact vorhanden & verifiziert)
```

- **qualified_candidates:** Paare mit `highest_contiguous_valid_gate == Q14` und terminalem
  Requalifikationsverdikt (`CHALLENGER_PROMOTED` oder `KEEP_INCUMBENT`). Kanonische Einheit =
  `(EA, Symbol)`; der Guard weist bis zur Vertragsratifikation zusätzlich distinct EAs und
  distinct Strategie-Familien aus (Direktive §6).
- **owner_order_artifact:** ein vorhandenes, signiertes
  `decisions/YYYY-MM-DD_owner_book_order_<venue>.md`, `venue ∈ {dxz, ftmo}`. Das Buch wird nur
  für die beauftragte(n) Venue(s) gebaut.
- Der frühere **Q11-Auto-Trigger bei 5 Q10-Paaren ist aufgehoben** (im Code bereits nicht mehr
  vorhanden; jetzt explizit verboten). Unter 25 darf der Pool nur **gemessen/vervollständigt**
  werden; kein Probe-Buch.
- Implementierung: ein `book_build_guard` vor `deploy_tlive_book.py` und jedem Q15-Analytik-Eintritt.

> **Lese-Hinweis:** Der Fließtext unten ist der verbatim v3-Text und nennt dieses Gate „Q11",
> den Optimierungsabschluss „Q16" und die Kette „Q14→Q15→Q16→Q11". v4-Entsprechung: dieses Gate
> = **Q15**, terminales Optimierungsgate = **Q14**, Kette = **Q12→Q13→Q14**, Operational
> Readiness = **Q16**, Live Burn-In = **Q17**. Storage-Lanes `Q11_DXZ`/`Q11_FTMO` →
> `Q15_DXZ`/`Q15_FTMO`. Mapping: [[Gate Manifest v4 Diff]].

---

**Analysis owner:** Claude (nur nach ausdrücklichem OWNER-Buchbau-Auftrag)
**Decision owner:** OWNER (selects EAs into portfolio)
**Trigger:** OWNER-Auftrag **und** Pool von mindestens 25 vollständig requalifizierten Kandidaten
**Input:** terminaler Optimierungs-/Requalifikationspool (im v3-Ist: Q16; v4-ID: Q14)
**Spec version:** 2026-08-23 (OWNER book-trigger supersession; Nummerierung wird neu geordnet)

> **OWNER-Direktive 2026-08-23:** Der frühere Auto-Trigger ab fünf Q10-Paaren ist aufgehoben.
> Kein DXZ-/FTMO-Probe- oder Zielbuch unter 25 vollständig qualifizierten Kandidaten und
> kein Buchbau ohne ausdrücklichen OWNER-Auftrag. Kandidatenzählung weist bis zur endgültigen
> Vertragsratifikation `(EA, Symbol)`, distinct EAs und Strategie-Familien getrennt aus.
> Die Bezeichnung Q11 war während der Rebaseline nur die historische v3-ID; der verpflichtende
> Hauptpfad ist unter v4 linear neu nummeriert (dieses Gate = Q15). Volltext:
> [[Pipeline Rebaseline Directive 2026-08-23]].

> **DL-089 (2026-08-21, `decisions/DL-089_live_book_full_chain_requalification.md`):** Für die
> Buch-Eignung des aktuellen Live-Buchs (21 EAs / 24 Sleeves) ist der Optimierungszweig
> **verpflichtend**, nicht optional. Buch-fähig ist nur, wer die vollständige aktuelle Kette
> trägt: Rebuild auf dem aktuellen Framework → Q02…Q10 → **Q14 → Q15 → Q16** → Q11 →
> OWNER-Buchzeremonie. Inkumbenz ist kein Beweis. Die Requalifikation läuft als **paralleler
> Track in der Fabrik auf rebuilten Binaries** — die 21 Live-Binaries handeln unberührt weiter.

---

## Purpose

Diese Portfolio-Bewertungsseite beschreibt die Portfolioanalyse. Sie beginnt erst, wenn die
vollständige aktuelle Optimierungs-/Requalifikationskette abgeschlossen ist, der qualifizierte
Pool mindestens 25 Kandidaten enthält und der OWNER den Buchbau ausdrücklich beauftragt.
Claude erzeugt dann den analytischen Fit-Report; vorher wird nur der Kandidatenpool gemessen
und vervollständigt.

**Diese Bewertung ist seit DL-084 (2026-08-12) dual-book:** DXZ und FTMO sind getrennte Lanes mit
eigenen Zulassungswegen und eigenen Storage-Lanes (`Q11_DXZ` / `Q11_FTMO`; v4: `Q15_DXZ` /
`Q15_FTMO`). Ein Sleeve kann in beiden Büchern erscheinen, wird aber je Buch separat zugelassen.

### Buch 1 — DarwinexZero (Fund-Motor)

Target **10–15 EAs** auf dem DarwinexZero-Live-€100k-Konto. Builder:
`tools/strategy_farm/portfolio/build_book_dxz.py` (capped inverse-vol + Cluster-Overlay +
fail-closed Incumbent-Gate „apply only if not worse"). Constraints: DXZ 5% Daily-DD /
20% Total-DD Kill-Rules (Hard-Rules-Amendment 2026-05-09).

### Buch 2 — FTMO (Cash-Motor)

Eigener Zulassungsweg, härtere Geometrie (10% Max Loss, 5% Daily Loss, interner
60/30-Tage-Sprintvertrag). Builder: `tools/strategy_farm/portfolio/build_book_ftmo.py` +
`ftmo_qualification.py` / `fund_score.py`: **FUND_SCORE ≥ 1.0**, Bootstrap
**P(Phase-1-Pass) ≥ 0.80** (konservative Untergrenze), FTMO-Q09-Admission
(`ftmo_q09_admission.py`) Pflicht. **Symbol-Regel (OWNER 2026-08-21): im FTMO-Buch
dürfen MEHRERE EAs/Strategien auf demselben Symbol laufen** — die Risikokontrolle
erfolgt auf Aggregat-Ebene (Korrelations-/Cluster-Kontrolle + kontoweites Risikobudget),
nicht über einen Symbol-Cap. *Code-Drift **beauftragt** 2026-08-21 (`OWNER-DEC-FTMO-SYMBOLPOLICY`,
Task `9bdfde03`): `build_book_ftmo.py` erzwingt bis zur Umsetzung noch `ONE_EA_PER_SYMBOL`
(`select_one_per_symbol`, Zeile 95/261). **Auflage an die Umsetzung:** der Cap wird nicht
ersatzlos gestrichen — er ist heute die einzige Konzentrationskontrolle des Builders; die
Aggregat-Kontrolle muss ihn ersetzen, und jedes ausgeschlossene Paar behält einen expliziten
Grund. Nicht ratifizierte Schwellen (Korrelationsgrenze, Risikobudget) werden vorgelegt, nicht
erfunden.* Kein Challenge-Kauf ohne OWNER (Geld = ROT).
Programmkontext: FTMO-Hindernisse-Analyse 2026-08-16 (Netto-Drift-Geometrie,
Kostenfidelity, atomares Konto-Risikobudget) — Masterplan `07_FTMO_Kampagne`.

**Beide Builder sind analytische Dry-Runs, fail-closed, können nicht deployen.** Die
Lanes `Q11_DXZ`/`Q11_FTMO` (v4: `Q15_DXZ`/`Q15_FTMO`) haben Stand 2026-08-21 noch 0 Rows
(warten auf die erste terminale Q16-/Q14-Kohorte) — der Ende-zu-Ende-Pfad ist ungeprobt.

## OWNER-Trigger Rule (supersedes auto-trigger 2026-08-23)

Diese Bewertung wird nicht pro EA und nicht automatisch ausgelöst. Claude misst den vollständig
requalifizierten Pool, baut aber erst nach ausdrücklichem OWNER-Auftrag und bei mindestens
25 qualifizierten Kandidaten ein DXZ-/FTMO-Analysebuch:

1. Bind the final requalification-PASS rows and prove the ≥25 threshold.
2. Compute correlation matrix + family clustering + symbol coverage + marginal Sharpe + ENB.
3. Generate the portfolio fit report (markdown + visualisations) at `D:/QM/reports/portfolio/q11_fit_<date>.md`.
4. Notify OWNER: "Portfolio fit report ready — N candidates, M slots open."
5. OWNER reads, decides, signs off → selected pairs advance to Q12 (v4: **Q16 Operational Readiness**).
6. Rejected pairs stay in the qualified pool and may be reconsidered in the next OWNER cycle.

---

## Diversification Rules (Hard)

| Rule | Value |
|---|---|
| **Family Cap** | Max **3 EAs** from the same strategy family (e.g. not more than 3 momentum EAs) |
| **Symbol Cap** | Max **2 EAs** simultaneously on the same symbol |
| **Pairwise correlation** | **\|r\| < 0.5** between any two EAs' Q10 equity curves (daily P&L) |
| **Total target** | 10-15 EAs in the live portfolio |

These caps are non-negotiable. An EA that would violate a cap waits in the Q10 pool until another EA exits the portfolio.

---

## Analysis Prepared for OWNER

Claude prepares the portfolio fit report:

1. **Correlation matrix** of all Q10-PASS (EA, symbol) equity curves
2. **Family clustering** — which EAs belong to which strategy family
3. **Symbol coverage** — how many EAs currently trade each symbol
4. **Marginal Sharpe** — what each candidate EA adds to the portfolio Sharpe
5. **Effective N of Bets (ENB)** — diversification quality metric
6. **Risk budget allocation** — proposed per-EA risk percentage (totals consistent with DXZ 5% daily / 20% total DD constraints)

Output: `D:/QM/reports/portfolio/q11_fit_<date>.md` with markdown tables + visualisations.

---

## OWNER Decision Process

1. OWNER reads the portfolio fit report.
2. OWNER decides which (EA, symbol) pairs join the portfolio, in what order.
3. OWNER records the decision under `decisions/YYYY-MM-DD_q11_portfolio_<batch>.md` with:
   - Selected EAs and risk allocation
   - Reasoning for inclusion/exclusion
   - Expected portfolio Sharpe / max DD
4. Selected EAs advance to Q12 Operational Readiness (v4: **Q16**).

---

## What Q11 explicitly does NOT do

- ❌ Auto-promote highest-PF EAs (OWNER decides)
- ❌ Violate the hard caps (no exceptions)
- ❌ Include any EA that hasn't cleared Q10 (v4: Q11 Incumbent Full-History Confirmation und die terminale Q14-Requalifikation)

---

## After Q15 PASS (v3: „After Q11 PASS")

- (EA, symbol) pair advances to Q16 Operational Readiness (v3: Q12) with the OWNER-decided risk percentage.

## Q15 "FAIL" semantics (v3: „Q11")

There is no FAIL at this gate — an (EA, symbol) pair either gets selected for the portfolio (advance to Q16 Operational Readiness) or stays in the qualified pool waiting for portfolio capacity. Selection rounds happen as portfolio slots free up.
