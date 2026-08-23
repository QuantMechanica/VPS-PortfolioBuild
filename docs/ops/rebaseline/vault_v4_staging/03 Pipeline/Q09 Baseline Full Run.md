# Q09 — Baseline Full Run

> **Gate-Manifest v4 (linear, 3 Makrophasen) — Staging-Entwurf.** Aktiver Runtime-Vertrag
> bleibt bis zur OWNER-Ratifikation v3 (`gate_manifest.v3.json`, `default_manifest_switch=false`).
> Diese Seite spiegelt den v4-Vertrag `tools/strategy_farm/config/gate_manifest.v4.draft.json`.

| Feld | Wert |
|---|---|
| **v4 Gate-ID** | Q09 |
| **Makrophase** | 2 · Strategie wird optimiert / requalifiziert (Phasenkopf) |
| **v3-Herkunft** | Q10A — „Baseline Full Run" (Anzeige-/Evidenzrolle, `source_phase` Q08) |
| **gate_contract_version** | v4 (historische v3-Zeilen behalten ihre Bedeutung über `gate_contract_version`) |
| **Evidence-Rolle** | `PRE_NEWS_FULL_HISTORY_BASELINE` |
| **Navigation** | ← [[Q08 Davey Statistical Validation]] · → [[Q10 News Impact + FTMO Recommendation]] |

**Herkunft:** v4 Q09 = v3 `Q10A` (Baseline Full Run). In v3 war `Q10A` eine reine
Anzeige-/Evidenz-Bindung **ohne** schreibbare `work_items.phase` (`write_phase_id("Q10A")`
war fail-closed). v4 **promoviert** die Stufe zu einem echten, schreibbaren linearen Gate an
Position Q09 und beseitigt damit die von der Rebaseline-Direktive verbotene Reihenfolge
„Q10A steht vor Q09" (Direktive §3). **Keine Kriterien-/Schwellenänderung (ROT):** die
Baseline ist derselbe Vollhistorienlauf wie bisher.

---

**Gate Owner:** Pipeline-Op (automated)
**Data window:** Volle verfügbare Historie je Symbol (2017 → present), pre-news
**Spec version:** 2026-08-23 (v4-Linearisierung; Evidenzinhalt = v3 Q10A / OWNER E3 2026-08-22)

---

## Purpose (OWNER-Wortlaut 2026-08-22, Zielreihenfolge E3)

Q09 ist der **Gesamtlauf VOR dem Newsfilter** — die target-neutrale, eingefrorene
Referenz-Baseline über die volle Historie, gegen die der spätere versiegelte
Vorher-/Nachher-Vergleich (Q14 Best-Settings Head-to-Head) misst. Q09 fügt keine neuen
Filter hinzu und optimiert nichts; es fixiert den Ausgangszustand der Optimierungsphase.

Q09 ist damit der erste Schritt der Makrophase 2. Die eigentliche News-Selektion folgt in
Q10, die Incumbent-Bestätigung in Q11.

---

## Reuse-Regel (fail-closed)

| Situation | Regel |
|---|---|
| Hash-gebundene Q08-Full-History-Baseline vorhanden und vertrags-/hash-gleich | **`REUSE_ONLY_HASH_BOUND_FULL_HISTORY_Q08_BASELINE`** — die eingefrorene Q08-Baseline wird direkt als Q09-Evidenz gebunden, kein neuer Lauf. |
| Keine passende hash-gebundene Baseline | **`REQUIRE_Q10A_BASELINE_RUN`** (fail-closed): ein Baseline-Lauf wird ausgeführt. Die Baseline wird **niemals aus einem Verdikt inferiert.** |

Die Wiederverwendbarkeit ist genau dann gegeben, wenn Kriterien vertragsgleich (ROT:
Schwellen unverändert) **und** Build-/Setfile-/Fenster-Hashes identisch sind
(`contract_equivalence.v3_to_v4`, `Q10A → Q09`).

---

## Hard Gate Criteria

| Criterion | Threshold / Regel |
|---|---|
| **Fenster** | Volle verfügbare Historie je Symbol (2017 → present) |
| **Parameter** | Q03 plateau-median (locked; nicht re-optimiert) |
| **Kosten/Stress** | Gross-Baseline konsistent mit der Q08-Full-History-Baseline; keine News-Filter, kein synthetischer Stress |
| **News** | KEINE — dies ist der pre-news-Lauf (News-Selektion erst in Q10) |
| **Evidenzbindung** | Build-Hash + Setfile-Hash + Datenfenster + Parent-Evidenz (Q08-Baseline) + `gate_contract_version=v4` |

**Per-symbol.** Läuft je `(EA, Symbol)` aus der Q08-PASS-/FAIL_SOFT-Menge.

---

## What Q09 explicitly does NOT do

- ❌ News-Filter anwenden (das ist Q10)
- ❌ Parameter re-optimieren (Q03 plateau-median locked)
- ❌ Die Baseline aus einem Verdikt ableiten (fail-closed: gebundene Q08-Baseline oder echter Lauf)
- ❌ Ein Portfolio- oder Live-Verdikt fällen

---

## After Q09

- Evidenz gebunden → weiter zu **Q10 News Impact + FTMO Recommendation**. Die Q09-Baseline
  bleibt als Referenz für den terminalen Q14-Vergleich (`SEALED_BEST_SETTINGS_VS_BASELINE_AND_INCUMBENT`) gebunden.
