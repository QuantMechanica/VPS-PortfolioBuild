# Q14 — Best-Settings Head-to-Head + Holdout

> **Gate-Manifest v4 (linear, 3 Makrophasen) — Staging-Entwurf.** Aktiver Runtime-Vertrag
> bleibt bis zur OWNER-Ratifikation v3 (`gate_manifest.v3.json`, `default_manifest_switch=false`).
> Diese Seite spiegelt den v4-Vertrag `tools/strategy_farm/config/gate_manifest.v4.draft.json`.

| Feld | Wert |
|---|---|
| **v4 Gate-ID** | Q14 — **terminales Phase-2-Gate (`next = null`)** |
| **Makrophase** | 2 · Strategie wird optimiert / requalifiziert (Abschluss) |
| **v3-Herkunft** | Q16 — „Best-Settings Head-to-Head" |
| **gate_contract_version** | v4 (historische v3-Zeilen behalten ihre Bedeutung über `gate_contract_version`) |
| **Referenz-Baseline** | Q09 (Baseline Full Run, pre-news) **und** Incumbent-Q11 |
| **Verdicts** | `CHALLENGER_PROMOTED` · `KEEP_INCUMBENT` (kein Fortschritt = gültiges Requal-Verdikt) |
| **Navigation** | ← [[Q13 Parameter Optimization & Freeze]] · → **kein per-EA-Nachfolger** (Buch-Eintritt Q15 nur über Buch-Trigger) |

**Herkunft:** v4 Q14 = v3 Q16 (Best-Settings Head-to-Head), H2H-Schwellen/Verdikte unverändert
(ROT).

> **v4-Präzisierung (OWNER-Direktive 2026-08-23):** Q14 ist das **terminale per-EA-Gate** der
> Makrophase 2. Die v3-Rückkante „Ergebnis kehrt zu Q11 zurück" (Rücksprung Q16→Q11) ist
> **entfernt** — es gibt keinen automatischen per-EA-`next`-Edge in Phase 3. `KEEP_INCUMBENT`
> (keine Verbesserung) ist ein gültiges terminales Requalifikationsergebnis. Der Eintritt in die
> Buchbewertung (Q15) erfolgt ausschließlich über den fail-closed Buch-Trigger
> (≥25 vollständig requalifizierte Kandidaten **und** OWNER-Buchauftrag), nicht über dieses Gate.
> Der Fließtext unten ist der verbatim v3-Text und nennt das Gate „Q16" und „zurück in Q11";
> v4: dieses Gate = **Q14**, Referenz-Baseline = **Q09**, Buch = **Q15** (nur Buch-Trigger).
> Mapping: [[Gate Manifest v4 Diff]].

---

**Authority:** Pipeline  
**Kanonisch:** `decisions/2026-08-12_DL-084_optimization_track_q14_q16_dual_book.md`

## Zweck

Q16 vergleicht einen Q10-bestandenen Challenger versiegelt mit seinem eingefrorenen
Incumbent. Das Gate beantwortet, ob die Optimierung außerhalb des Auswahlfensters und im
Portfoliokontext tatsächlich einen Mehrwert liefert.

## Vergleich

- identische vorregistrierte OOS-Fenster und reale Kosten,
- verpflichtende No-Change-Kontrolle,
- Q04-Folds plus Post-DEV-Holdout,
- Drawdown, Worst Day, Frequenz und robuste Ergebnismaße,
- regimegeteilte Korrelation und Portfolio-Marginalbeitrag,
- vollständige Trial-Budget-Bindung gegen Überanpassung.

Referenz-Baseline unter v4: der **Q09 Baseline Full Run (pre-news)** UND die
**Incumbent-Q11-Confirmation** (`SEALED_BEST_SETTINGS_VS_BASELINE_AND_INCUMBENT`).

## Verdicts

- `PROMOTE_CHALLENGER` (v4-Kanon: `CHALLENGER_PROMOTED`),
- `KEEP_INCUMBENT` — keine Verbesserung, **gültiges terminales Requal-Verdikt**,
- `ADMIT_BOTH` nur bei unabhängiger, positiver Buchwirkung,
- `FAIL` bei unvollständiger oder ungültiger Evidenz.

## Übergang

**Terminal (v4).** Das Verdikt schließt die per-EA-Optimierungs-/Requalifikationskette ab
(`next = null`). Es tauscht niemals automatisch einen Live-Sleeve aus; Buchbewertung (Q15),
Book Manifest, Operational Readiness (Q16) und Live Burn-In (Q17) bleiben getrennte
OWNER-Zeremonien und werden nur über den fail-closed Buch-Trigger erreicht — nicht durch einen
Rücksprung.

*(v3-Wortlaut, superseded: „Das Ergebnis fließt zurück in Q11." Diese Rückkante ist unter v4
entfernt.)*
