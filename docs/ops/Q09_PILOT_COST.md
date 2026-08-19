# Q09_PILOT_COST — was eine Q09_NEWS-Zeile kostet, und warum der Pilot an einer Entscheidung hängt

**Stand:** 2026-08-19 · Work Order Runde 8 §4
**Quellen:** `tools/strategy_farm/q09_news_runner.py`, `q09_news_contract.py`,
`farm_state.sqlite` (read-only),
`docs/ops/evidence/2026-08-17_phase1_1_q09_news_closure_has_no_operator_and_costs_19_to_36_days.md`

---

## 0 · Die drei Sätze

> **Der Pilot ist vorbereitet, aber nicht gefahren** — er hängt an genau dem Parameter, den du dir
> vorbehalten hast: `--deployment-target` entscheidet über **40 oder 145 Testerzellen** je Zeile,
> also über den Faktor 3,6 in den Kosten. Das ist keine Formalie, sondern die Kostenentscheidung
> selbst.
>
> **Elf der vierzehn Eingaben sind aus dem Bestand ableitbar.** Zwei brauchen eine Festlegung,
> eine ist ungeklärt.
>
> **Und der 08.08. war kein Bruch:** es gibt in der gesamten Historie **genau eine** erfolgreiche
> Q09_NEWS-Schließung. Die Servicerate war nie ungleich null.

---

## 1 · Die zwei ökonomischen Parameter — enumeriert, nicht gewählt (§4.2)

### 1.1 `--deployment-target` — kein Etikett, sondern der Kostenschalter

Zulässige Werte, aus `q09_news_contract.py:50-58` (`TARGET_COMPLIANCE`):

| Eingabe | wirksamer Compliance-Modus | Zellen je Zeile |
|---|---|---:|
| `RESEARCH` · `NONE` | NONE | **40** |
| `DXZ` · `DARWINEXZERO` · `DARWINEX_ZERO` | DXZ | **40** |
| **`FTMO`** | FTMO | **145** |
| `5ERS` · `THE5ERS` · `THE_5ERS` | 5ERS | **145** |

**Die Wirkung ist zweifach, und die zweite ist die teure:**

1. Er wählt den Compliance-Modus, unter dem die `POLICY_ON`-Zellen laufen
   (`compliance_for_target`).
2. `_is_prop_target()` (`q09_news_runner.py:183`) erzwingt für **FTMO und 5ERS** die
   **erweiterte Matrix**: `_cell_specs` fährt dann *alle vier* Compliance-Modi statt nur des
   Zielmodus.

Rechnung aus `_cell_specs` mit `TEMPORAL_MODES` = 7, `SEEDS` = 5, `COMPLIANCE_MODES` = 4:

* nicht-prop: 5 Kontrollzellen + 1 × 7 × 5 = **40**
* prop: 5 + 4 × 7 × 5 = **145**

> **Antwort auf deine Frage, ob es nur ein Etikett ist: nein.** FTMO kostet das 3,6-fache an
> Testerzeit gegenüber DXZ, bei identischem Kandidaten.

### 1.2 `--cost-profile` — hier ist es tatsächlich ein Etikett

**[BEFUND]** Der Wert wird **nirgends validiert**. Er wird durchgereicht und landet in
`report_manifest.json` und `cell_evidence.json` (`q09_news_runner.py:2486`, `:2506`) — als
Beschriftung neben `cost_execution_identity_sha256`. Keine Enumeration, keine Prüfung, keine
Wirkung auf das Kostenmodell des Testers; das kommt aus Setfile und Tester-Konfiguration.

Der einzige im Code verwendete Wert ist **`DXZ_CANONICAL_REAL_TICKS_V1`**
(`q09_live_news_backfill.py:478, 1424, 1842`).

**Deine Steuerung „im Zweifel den konservativsten" lässt sich hier also nicht anwenden**, weil es
keine Auswahl gibt. Was bleibt, ist Vergleichbarkeit: denselben Wert nehmen wie die eine
erfolgreiche Schließung. Falls du wolltest, dass das Kostenprofil *tatsächlich* konservativ ist,
liegt der Hebel nicht hier, sondern im Setfile und in `tester_defaults.json` — das wäre eine eigene
Prüfung, und ich habe sie nicht angefasst.

---

## 2 · Der 08.08., datiert (§4.3) — und die Prämisse fällt

**[MESSUNG]** Alle terminalen Q09_NEWS-Zeilen der Historie:

| Monat | Verdikt | Zeilen |
|---|---|---:|
| 2026-07 | `PENDING_RUNNER` | 18 |
| 2026-08 | **`CONFIG_LOCKED`** | **1** |
| 2026-08 | `INFRA_FAIL` | 24 |
| 2026-08 | `INVALID_EVIDENCE` | 1 |
| 2026-08 | `REVIEW_REQUIRED` | 39 |

> **Genau eine Zeile ist jemals durch Q09_NEWS gekommen:** `QM5_11422/USDCAD`, Work Item
> `44e2c70d`, geschlossen **2026-08-08T07:41:49Z**, 145 Zellen, `chosen_temporal: OFF`,
> `chosen_compliance: DXZ`.

**Damit korrigiere ich meine eigene Meldung aus der Monitoring-Runde.** Ich hatte „Servicerate null
seit elf Tagen" gemeldet und damit impliziert, dass vorher etwas lief. Das stimmt nicht: die 83
terminalen Zeilen sind Platzhalter (`PENDING_RUNNER`), Infrastrukturfehler und Review-Marken. Der
08.08. ist kein Bruch, sondern **die einzige Bedienung, die je stattgefunden hat** — von Hand, in
einer Session.

**Antwort auf §4.3, wie du sie vorweggenommen hast:** Q09_NEWS wurde immer nur in Claude-Sessions
bedient, und zwar genau einmal. Es gehört damit **als Designentscheidung offengelegt**, nicht als
Rückstand geführt — dieselbe Klasse wie der `review_ea`-Stau, nur ohne die 56 Vorgänger.

---

## 3 · Der Pilot — Stand und was ihn blockiert (§4.1)

Kandidat: **QM5_11294 / XAUUSD.DWX** (`cs-ichi-cloud`), Q08 PASS am 19.08. 09:43,
Q09_NEWS-Zeile `46409fc4` pendent.

### 3.1 Die vierzehn Eingaben, klassifiziert

| Eingabe | Status | Quelle |
|---|---|---|
| `--work-item-id` | **ableitbar** | `46409fc4…` aus `work_items` |
| `--q08-work-item-id` | **ableitbar** | `d0f55c10…`, Q08 PASS |
| `--ex5` | **ableitbar** | Q08-Payload `expected_ex5_path` → `framework\EAs\QM5_11294_cs-ichi-cloud\…ex5` |
| `--baseline-setfile` | **ableitbar** | EA-Verzeichnis |
| `--calendar-manifest` | **ableitbar** | `D:\QM\data\news_calendar\news_calendar_bundle_manifest.json` |
| `--calendar-common-relative-path` | **ableitbar** | aus dem Bundle-Manifest |
| `--candidate-lineage-key` | **ableitbar** | (EA, Symbol) |
| `--complete-months` / `--holdout-complete-months` | **ableitbar per Präzedenz** | 60 / 24 wie bei der Schließung vom 08.08. |
| `--tester-model` | **ableitbar per Präzedenz** | `FACTORY_RESERVED_RUN_SMOKE_MODEL4_THREE_WINDOWS_V1` |
| `--output-root` | trivial | |
| **`--cost-profile`** | **Festlegung** | unvalidiertes Etikett; Präzedenz `DXZ_CANONICAL_REAL_TICKS_V1` |
| **`--deployment-target`** | **deine Entscheidung** | entscheidet 40 gegen 145 Zellen |
| `--q08-evidence` | **ungeklärt** | Pfad zur Q08-Evidenzdatei noch nicht lokalisiert |
| `--include-closure` | **ungeklärt** | welche Datei hier erwartet wird, ist mir noch nicht klar |

**Elf ableitbar, zwei Festlegungen, eine offene Pfadfrage** — das ist die Antwort auf „sind die
restlichen 20 Fließarbeit oder Einzelfälle": **Fließarbeit**, sobald die zwei Festlegungen einmal
getroffen sind. Der Aufwand je weiterer Zeile ist Skriptarbeit, keine Einzelfallentscheidung.

### 3.2 Fabrikzeit je Zeile — hochgerechnet aus der einen echten Schließung

Aus `2026-08-17_phase1_1_…`: beobachtet **~9.250 Zellen ≈ 865 h** für den Pool → **≈ 5,6 min je
Zelle**.

| Ziel | Zellen | **Fabrikzeit je Zeile** | 21 Zeilen |
|---|---:|---:|---:|
| DXZ / RESEARCH | 40 | **≈ 3,7 h** | ≈ 78 h ≈ **3,3 Tage** |
| FTMO / 5ERS | 145 | **≈ 13,5 h** | ≈ 284 h ≈ **11,8 Tage** |

Bei der heute gemessenen Flottenrate (§5.2: 19,6 terminale Zeilen/h über zehn Terminals) ist das
**kein Randposten**: 284 Stunden Q09 blockieren die Fabrik für die Dauer, in der sie sonst rund
5.500 gewöhnliche Gate-Zeilen abarbeitet.

> **Das ist die Zahl, die die Work Order verlangt hat, und sie sagt: Q09 auf FTMO-Ziel für alle
> 21 Zeilen ist der teuerste Einzelposten im laufenden Betrieb.**

### 3.3 Meine Zeit je Zeile

Nach der ersten Zeile: **gering.** Elf ableitbare Eingaben lassen sich in einem Wrapper erzeugen,
der (EA, Symbol) nimmt und den Plan baut. Der Aufwand liegt einmalig im Wrapper, nicht je Zeile.
Das ist der Vorschlag zur Automatisierung, den §4.1 verlangt — **vorgelegt, nicht gebaut.**

### 3.4 Warum ich nicht gefahren bin

`--deployment-target` ist die Kostenentscheidung, und du hast sie dir ausdrücklich vorbehalten.
Sie jetzt selbst zu setzen hieße, den Faktor 3,6 an dir vorbei zu entscheiden — bei einem Posten,
der zwischen 3,3 und 11,8 Fabriktagen liegt.

**Was ich zur Entscheidung beitragen kann:**

* Die einzige erfolgreiche Schließung lief mit **145 Zellen und wählte am Ende `DXZ`** als
  Compliance und `OFF` als Temporalmodus. Die teure Matrix hat dort also **kein** FTMO-spezifisches
  Ergebnis erbracht, sondern DXZ bestätigt.
* `UPPER_BOUND_CALC.md` kennt die Grenze des FTMO-Buchs; das DZ-Buch ist unbewertet
  (`DZ_BOOK_SCOPE.md`). Ein FTMO-Ziel würde also für eine Spur bezahlen, deren Obergrenze bereits
  bekannt ist.
* Bei `DXZ` kostet der Pilot **3,7 Fabrikstunden**, bei `FTMO` **13,5**.

**Empfehlung: `DXZ` für den Piloten** — billiger, und der Präzedenzfall hat DXZ ohnehin gewählt.
Wenn der Pilot trägt, ist die FTMO-Matrix für ausgewählte Kandidaten immer noch nachrüstbar.
**Nicht gesetzt; ich warte auf deine Wahl.**

---

## 4 · Was sonst noch auffiel

* **Eine Dublette in der Warteschlange:** `QM5_12354/XAUUSD.DWX` steht **zweimal** als pendente
  Q09_NEWS-Zeile (beide 18.08. 07:26:56). Bei 40 bis 145 Zellen je Zeile ist eine doppelte
  Ausführung teuer. → **OQ-21**
* **39 Zeilen tragen `REVIEW_REQUIRED`** in Q09_NEWS — sie warten nicht auf den Runner, sondern auf
  einen Review. Das ist eine zweite, bisher nicht benannte Warteschlange vor demselben Gate.
* Die pendente Menge ist **21 Q09_NEWS + 4 Q09_PORTFOLIO**, davon zwei frisch von QM5_11294
  (XAUUSD und GDAXI, beide heute).
