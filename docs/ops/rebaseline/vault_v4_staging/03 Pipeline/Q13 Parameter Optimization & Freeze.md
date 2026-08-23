# Q13 — Parameter Optimization & Freeze

> **Gate-Manifest v4 (linear, 3 Makrophasen) — Staging-Entwurf.** Aktiver Runtime-Vertrag
> bleibt bis zur OWNER-Ratifikation v3 (`gate_manifest.v3.json`, `default_manifest_switch=false`).
> Diese Seite spiegelt den v4-Vertrag `tools/strategy_farm/config/gate_manifest.v4.draft.json`.

| Feld | Wert |
|---|---|
| **v4 Gate-ID** | Q13 |
| **Makrophase** | 2 · Strategie wird optimiert / requalifiziert |
| **v3-Herkunft** | Q15 — „Parameter Optimization & Freeze" (v2-Name: „Challenger Build & Freeze") |
| **gate_contract_version** | v4 (historische v3-Zeilen behalten ihre Bedeutung über `gate_contract_version`) |
| **Navigation** | ← [[Q12 Pattern Filter Selection]] · → [[Q14 Best-Settings Head-to-Head]] |

**Herkunft:** v4 Q13 = v3 Q15 (Parameter Optimization & Freeze), DEV/IS-only-Sweep +
Freeze-Kontrakt unverändert (ROT). „Keine Änderung" ist ein gültiges Ergebnis.

> **Lese-Hinweis:** Der Fließtext ist der verbatim v3-Text und nennt das Vorgänger-Gate „Q14"
> und die Challenger-Kaskade „Q02 → Q10". v4-Entsprechung: Vorgänger = **Q12**, Challenger-Kaskade
> unverändert Q02→Q11 (Confirmation), Nachfolger = **Q14 Best-Settings Head-to-Head**. Mapping:
> [[Gate Manifest v4 Diff]].

---

**Authority:** Development  
**Kanonisch:** `docs/ops/Q15_CHALLENGER_BUILD_SOP_2026-08-12.md`

## Zweck

Aus einer Q14-Opt-Card entsteht eine neue, eigenständig registrierte EA-Identität. Die
Auswahl erfolgt ausschließlich im DEV/IS-Fenster; danach werden Inputs und Evidenz
kryptografisch gebunden.

## Pflichtartefakte

- neue EA-ID, Magic-Registry-Zeilen, Source, Binary und Setfiles,
- vollständiger vorregistrierter DEV-Sweep,
- Plateau-Auswahl statt einzelner Bestwertauswahl,
- Default-OFF-Äquivalenz zum gebundenen Parent,
- Freeze-Addendum mit Hashes und geschlossenem Trial Ledger,
- sichere Fixed-Risk-Q02-Konfiguration.

## Harte Grenzen

- ein Build zur Zeit,
- Builder und Approver sind getrennt,
- keine OOS-Ergebnisse während der Auswahl,
- kein Überspringen oder Abschwächen eines Standardgates,
- keine Live-Setfiles, kein Deploy und kein Terminal-Control.

## Übergang

`CHALLENGER_SPAWNED` erzeugt genau einen Q02-Start für den Challenger. Dieser muss den
unveränderten Standardweg Q02 → Q10 mit eigener Evidenz bestehen, bevor Q16 möglich ist
(v4: Standardweg Q02 → **Q11 Incumbent Full-History Confirmation**, danach
**Q14 Best-Settings Head-to-Head**).
