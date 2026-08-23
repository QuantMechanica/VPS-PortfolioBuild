# Q12 — Pattern Filter Selection

> **Gate-Manifest v4 (linear, 3 Makrophasen) — Staging-Entwurf.** Aktiver Runtime-Vertrag
> bleibt bis zur OWNER-Ratifikation v3 (`gate_manifest.v3.json`, `default_manifest_switch=false`).
> Diese Seite spiegelt den v4-Vertrag `tools/strategy_farm/config/gate_manifest.v4.draft.json`.

| Feld | Wert |
|---|---|
| **v4 Gate-ID** | Q12 |
| **Makrophase** | 2 · Strategie wird optimiert / requalifiziert |
| **v3-Herkunft** | Q14 — „Pattern Filter Selection" (v2-Name: „Optimization Admission") |
| **gate_contract_version** | v4 (historische v3-Zeilen behalten ihre Bedeutung über `gate_contract_version`) |
| **Auswahl-Kontrakt** | DL-089 (unverändert, ROT) · Obergrenze **3 Filter je Richtung** |
| **Navigation** | ← [[Q11 Incumbent Full-History Confirmation]] · → [[Q13 Parameter Optimization & Freeze]] |

**Herkunft:** v4 Q12 = v3 Q14 (Pattern Filter Selection), DL-089-Auswahlregel und Filter-Cap
unverändert (ROT).

> **v4-Präzisierung (OWNER-Direktive 2026-08-23):** In v3 war dies der **optionale** Fork-Eintritt
> (`EXPLICIT_Q14_ADMISSION`) ab Q10-PASS. In v4 ist Q12 ein **verpflichtender linearer Schritt**
> der Makrophase 2 — der Nachfolger von Q11 (Incumbent Full-History Confirmation). **Null
> ausgewählte Filter / kein zulässiger Filter ist ein gültiges Pass-Through-Ergebnis**, kein FAIL.
> Der Zweig springt nicht mehr zu einem Buch-Gate zurück; er läuft linear weiter zu Q13.
> Der Fließtext unten ist der verbatim v3-Text und nennt die Kette „Q14 → Q15 → Q16 → Q11";
> v4-Entsprechung: **Q12 → Q13 → Q14** (terminal), Buch erst in **Q15**. Mapping:
> [[Gate Manifest v4 Diff]].

---

**Authority:** Pipeline  
**Topologie:** verpflichtender linearer Schritt der Makrophase 2, Nachfolger von Q11 (v3: optionaler Zweig ab **Q10-PASS**, Fork-Punkt OWNER-bestätigt 2026-08-21, Masterplan-Entscheidung #5)  
**Kanonisch:** `decisions/2026-08-12_DL-084_optimization_track_q14_q16_dual_book.md`

> **DL-089 (2026-08-21, `decisions/DL-089_live_book_full_chain_requalification.md`):** Für die
> Buch-Eignung des aktuellen Live-Buchs (21 EAs / 24 Sleeves) ist der Optimierungszweig
> **verpflichtend**, nicht optional. Buch-fähig ist nur, wer die vollständige aktuelle Kette
> trägt: Rebuild auf dem aktuellen Framework → Q02…Q10 → **Q14 → Q15 → Q16** → Q11 →
> OWNER-Buchzeremonie. Inkumbenz ist kein Beweis. Die Requalifikation läuft als **paralleler
> Track in der Fabrik auf rebuilten Binaries** — die 21 Live-Binaries handeln unberührt weiter.

> **Numerik-Hinweis:** Diese Seite (wie Q13/Q14 in v4-Nummerierung; v3: Q15/Q16) ist bewusst
> qualitativ. Die numerischen Kriterien, Hebel-Definitionen und das Trial-Budget leben im
> DL-084-Entscheid, in `docs/ops/Q15_CHALLENGER_BUILD_SOP_2026-08-12.md` und in
> `tools/strategy_farm/config/opt_program.v1.json` (Runner:
> `framework/scripts/q14_opt_admission.py` / `q15_freeze_check.py` / `q16_head_to_head.py`).
> Stand 2026-08-21: 14 Q14-Rows (11 `OPT_ELIGIBLE`), 1 Challenger gespawnt, Q16 wartet
> auf die eigene Q02→Q10-Kaskade des Challengers.
> Hebel-Status (Stand 2026-08-21): **im Code implementiert** (Runner unterstützt sie) sind
> EXIT_SURGERY, VOL_REGIME_FILTER, LOCKED_PORT, MTF_ENTRY **inkl. PREDICATE_ABLATION**.
> **Im laufenden `opt_program.v1.json` aktiviert** (`enabled:true`) sind nur EXIT_SURGERY,
> VOL_REGIME_FILTER, LOCKED_PORT, MTF_ENTRY — **PREDICATE_ABLATION ist code-seitig
> vorhanden, aber im Programmvertrag nicht freigeschaltet**. Die Erweiterung um
> PATTERN_FILTER_COMBO (bis 3 Prädikate), NEWS_FILTER und numerische AI_PARAM-Surfaces ist
> Masterplan T7/T9 (GELB-Bedingungen: Hypothese, Widerlegungskriterium, Frequenzprüfung,
> Parameterzahl).

## Zweck

Q14 lässt nur belastbare Q10-PASS-Paare in ein vorregistriertes Optimierungsprogramm.
Optimierung darf keine Rettungsstrecke für frühere Gate-Fehler sein.

## Eingänge

- eindeutiges `(ea_id, symbol)` mit aktuellem Q10 PASS,
- unveränderliche Card-, Build-, Setfile- und Reportbindungen,
- zulässiger Optimierungshebel mit wirtschaftlicher Hypothese,
- vollständige Historie und die im Programmvertrag verlangten Mindestdaten.

## Ergebnis

Ein deterministisches Opt-Card-Artefakt bindet Hypothese, Hebel, exakte Parametersurface,
Vergleichsfenster und geöffnetes Trial Ledger. Zulässige Verdicts sind
`OPT_ELIGIBLE` und `OPT_REJECTED`. **Null ausgewählte Filter (kein zulässiger Filter) ist ein
gültiges Pass-Through-Ergebnis (v4).**

## Harte Grenzen

- keine automatische Aufnahme unterhalb Q10,
- keine nachträgliche Erweiterung der Parametersurface,
- kein OOS-Lesen zur Auswahl,
- Dry-run bleibt read-only; Zustandsänderung verlangt den expliziten Apply-Vertrag,
- keine Terminal-, Deploy- oder Live-Aktion.

## Übergang

Nur `OPT_ELIGIBLE` erzeugt einen seriellen Q15-Buildauftrag (v4: **Q13 Parameter Optimization &
Freeze**). Q14 selbst ändert weder den Incumbent noch ein Portfolio.
