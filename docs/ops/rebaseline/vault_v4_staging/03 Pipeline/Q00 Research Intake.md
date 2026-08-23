# Q00 — Research Intake

> **Gate-Manifest v4 (linear, 3 Makrophasen) — Staging-Entwurf.** Aktiver Runtime-Vertrag
> bleibt bis zur OWNER-Ratifikation v3 (`gate_manifest.v3.json`, `default_manifest_switch=false`).
> Diese Seite spiegelt den v4-Vertrag `tools/strategy_farm/config/gate_manifest.v4.draft.json`.

| Feld | Wert |
|---|---|
| **v4 Gate-ID** | Q00 |
| **Makrophase** | 1 · Strategie beweist sich |
| **v3-Herkunft** | Q00 (Research Intake) — ID unverändert |
| **gate_contract_version** | v4 (historische v3-Zeilen behalten ihre Bedeutung über `gate_contract_version`) |
| **Navigation** | (Phasenkopf) · → [[Q01 Build & Spec]] |

**Herkunft:** v4 Q00 = v3 Q00 (Research Intake), ID und Kriterien unverändert (ROT).

---

**Gate Owner:** OWNER  
**Spec version:** R1–R4; R1/R2/R3 relaxed 2026-05-15; **R4 von OWNER 2026-08-21 explizit bestätigt** (bleibt binding).  
**Input:** Proposed research source (Buch, Paper, URL, Video)  
**Output:** APPROVED / REJECTED / PENDING Strategy Card

---

## Zweck

Q00 entscheidet ob eine Strategie-Quelle und die daraus extrahierten Strategien überhaupt weiter in die Pipeline dürfen. Es ist das Quality-Gate bevor Zeit in Q01 (Bau) investiert wird.

---

## QB Reputable Source Criteria (R1–R4) — relaxed 2026-05-15

> **Policy-Update 2026-05-15** — OWNER hat R1/R2/R3 entschärft. Q00 ist jetzt ein
> weites Netz; die Pipeline (Q02 Baseline, Q03+ statistical) ist der eigentliche
> Quality-Filter. R4 (HR14, NO ML) bleibt binding.

**Kanonische Quelle:** `C:/QM/repo/processes/qb_reputable_source_criteria.md`
(gewinnt bei Konflikt mit dieser Seite).

| Kriterium | PASS wenn… | REJECT nur wenn… |
|-----------|-----------|-----------------|
| **R1** Source-Attribution | **Egal wo die Strategie gefunden wurde — der Fundort IST die Quelle und muss angegeben werden** (OWNER 2026-08-21): verifizierbare URL / kanonische Referenz (Forum-Thread, Artikel, Paper, Buch+Kapitel, Video+Timestamp). Autor-Reputation ist **kein** Kriterium; anonyme Handles OK wenn verlinkt. | Keine Source-Attribution überhaupt — pure Erfindung, unbelegbar. |
| **R2** Mechanisch implementierbar | Directional Entry + Exit Regeln existieren. Lücken in Side-Params (ATR-Multiplier, Lookback, SL%) sind OK — Codex füllt Defaults, Q03 verfeinert. | Komplett discretionary, keine Regel überhaupt ("when market looks good"). |
| **R3** DWX-testbar (Porting erlaubt) | Strategie testbar auf ≥1 Darwinex CFD-Instrument **nach Portierung**. Krypto / Equity / Options Strategien die auf Forex/Indices/CFDs portieren = OK. | Strategie braucht fundamental ein nicht-CFD-Feature (Options-Chain, ETF-Flows, exchange-microstructure ohne Analog). |
| **R4** No ML, 1-pos-per-magic (HR14, BINDING) | Mechanische Regeln, fixe Params, kompatibel mit 1-Position-per-Magic-Convention. | ML / Neural / Adaptive Params / Online-Learning / Grid-ohne-bounded-worst-case. **Nicht relaxbar.** |

**Alle 4 müssen PASS sein** für Q00-APPROVED.

### Was sich geändert hat

- **R1**: forderte vorher verifizierbaren Autor-Track-Record (kein Anonymous, kein Blog-only). **Gedroppt 2026-05-15** — nur noch ein Link reicht.
- **R2**: forderte vorher Entry/Exit/Stop/Sizing alle explizit. **Relaxed 2026-05-15** — Gaps OK, Codex füllt.
- **R3**: forderte vorher dass die in der Quelle genannten Instrumente im DWX-Feed sind. **Relaxed 2026-05-15** — Portierung auf andere DWX-Instrumente erlaubt.
- **R4**: unverändert. HR14 binding. **OWNER hat am 2026-08-21 explizit entschieden: R4 bleibt** (Nachfrage im ULTRACODE-Audit, Masterplan-Entscheidung #1).

### Non-Retroactive

Cards die VOR dem 2026-05-15 unter den strikten Kriterien geprüft wurden, bleiben so wie sie waren. Diese Policy gilt nur für **neue** Q00-Verdicts.

---

## OWNER-Workflow

1. Lese Strategy Card (`strategy-seeds/cards/QM5_<NNNN>_<slug>.md`)
2. Prüfe R1–R4 gegen `processes/qb_reputable_source_criteria.md`
3. Vergib Verdict: APPROVED / REJECTED / PENDING
4. Schreibe Verdict als Closeout-Comment mit Begründung pro Kriterium
5. Update Card: `g0_status: APPROVED` (oder REJECTED/PENDING)
6. Bei APPROVED: Erstelle Q01-Issue und weise Development zu

Die zuständige AI bereitet Review und Evidenz vor; das Q00-Verdikt bleibt beim OWNER.

---

## Was passiert mit REJECTED Cards?

- Card bleibt in `strategy-seeds/cards/` mit `g0_status: REJECTED`
- OWNER-Entscheid nennt das gescheiterte R-Kriterium
- Card wird **nicht** gelöscht — ist historische Evidenz
- Kann bei neuen Informationen erneut vorgelegt werden

---

## Retroaktivität

Die R1–R4 Kriterien sind **nicht retroaktiv** — Strategien die vor der QB-Einführung APPROVED wurden, müssen nicht neu bewertet werden.

---

## Häufige FAIL-Gründe

| Kriterium | Häufiger Fail |
|-----------|--------------|
| R1 | Card ohne jede Quellenangabe (frei erfundene "Strategie") — ein Link genügt, Autor-Reputation ist seit 2026-05-15 KEIN Kriterium mehr |
| R2 | "Trade when RSI is low" — nicht mechanisch genug |
| R3 | Strategie braucht ein Feature ohne CFD-Analog (Options-Chain, ETF-Flows) — reine Instrument-Portierung ist dagegen OK |
| R4 | Strategie setzt ML-basierte Signale, adaptive Parameter oder unbegrenztes Grid voraus |
