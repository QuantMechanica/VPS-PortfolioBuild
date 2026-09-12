# DL-089 Nachtrag D — OHLC-M1-Vorsortierung vor dem Real-Tick-Zensus

**Status:** ENTWURF ZUR OWNER-UNTERSCHRIFT — nicht aktiv, keine Start- oder Queue-Autorität  
**Task:** `cb065930-391b-4048-b26f-24ddb064993d`  
**Vorgeschlagener Entscheid:** `OWNER-DEC-PRESCREEN-OHLC-20260911`  
**Basisplan:** `docs/research/PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md`  
**Evidenz:** `docs/ops/evidence/2026-09-11_t11_prescreen_pilot_orch.csv` und
`docs/ops/evidence/2026-09-11_prescreen_decision/PRESCREEN_PROTOCOL_DECISION_CARD_2026-09-11.md`

Dieser Text ist ein unterschriftsreifer Nachtrag, aber noch kein Bestandteil des
versiegelten DL-089-Plans. In dieser Arbeit wurden keine Tests gestartet, keine
Work-Items angelegt oder verändert und keine bestehende `MEASURED`-Zeile oder
Verdikt-Evidenz verändert.

## 1. Einzufügender Entscheidungstext

> **Nachtrag D — vorregistrierte OHLC-M1-Vorsortierung.** Für ein ausdrücklich
> vorregistriertes `OPT_CENSUS`-Programm darf vor den noch offenen Real-Tick-Zellen
> eine separate PRESCREEN-Klasse mit MT5 `Model=1` (OHLC-M1; ausdrücklich nicht
> `Model=2` Open Prices) laufen. Die Einheit der Rangbildung ist der vollständige
> Pattern×Richtung-Arm mit seinem deklarierten Jahresbündel; Jahre werden nicht
> gepoolt und einzelne schlechte Jahre dürfen nicht entfernt werden. Baseline,
> Elternarm, Pflichtkontrollen, Plateau-Nachbarn und alle Abhängigkeiten sind stets
> zu behalten.
>
> Vor dem ersten PRESCREEN-Claim werden Universum und Rangregel versiegelt. Der
> Startwert ist `keep_fraction=0.70`. Von den verworfenen Arm-Bündeln wird mit
> vorab gebundenem Seed eine einfache Zufallsstichprobe von
> `control_fraction_of_drops=0.10` gezogen und vollständig mit Real Ticks bestätigt.
> Cutoff-Gleichstände werden vollständig behalten; Keep- und Kontrollmengen werden
> immer auf ganze Arm-Bündel aufgerundet.
>
> PRESCREEN-Ergebnisse dürfen ausschließlich Reihenfolge und Umfang der nachfolgenden
> Real-Tick-Kandidaten bestimmen. Nur authentifizierte `Model=4`-Zellen dürfen als
> `MEASURED` gelten, die DL-089-Regeln ≥2/3 Jahre und ≥+5% anwenden, Verdikte erzeugen,
> `declared_trial_count`/DSR/PBO speisen, den Q14-Zähler verändern oder in ein Buch
> eingehen. Das ursprüngliche Trial-Universum von 154 Pattern×Richtung-Armen wird
> durch ein Screening nicht verkleinert.
>
> Nach jedem vollständig bestätigten Kontrollbündel wird die vorregistrierte
> False-Negative-Schätzung fortgeschrieben. Neue prescreen-abhängige Admissions werden
> sofort ausgesetzt, wenn (a) die gewichtete FNR mehr als 10% beträgt, (b) mehr als
> 10% der kontrollierten Drops die feste Real-Tick-Eignungsregel erfüllen oder (c)
> eine Kontrolle, Identität, Jahresvollständigkeit oder Lineage fehlt. Ein leerer
> Nenner ist `UNKNOWN`, nie null. Beobachtete False Negatives werden gerettet und
> vollständig auf Real Ticks gemessen.
>
> Rollback ist append-only: weitere PRESCREEN-Admissions sperren, Evidenz und
> Ranking-Snapshot erhalten, alle ausgelassenen Real-Tick-Bündel wieder über den
> normalen Deklarations-/Claimpfad zulassen und nach vollständiger Real-Tick-Matrix
> mit der unveränderten DL-089-Regel neu auswerten. Keine bestehende Zeile wird
> umgeschrieben oder gelöscht.

Die Zulässigkeit eines bereits teilweise gemessenen Programms ist zusätzlich
fail-closed: sein noch offenes Arm-Universum muss vor dem ersten PRESCREEN-Ergebnis
deterministisch kompiliert und gegen bereits bekannte Real-Tick-Ergebnisse für die
Ranking-Funktion gesperrt werden. Kann dieser Outcome-Embargo nicht nachgewiesen
werden, bleibt das Programm vollständig im Real-Tick-Pfad. Der Nachtrag allein
autorisiert keinen retroaktiven Umbau.

## 2. Exakte Vorregistrierungs- und Ledger-Felder

Jede Programmdeklaration erhält append-only einen selbst gehashten Block
`prescreen_declaration` mit mindestens:

| Feld | Versiegelter Wert / Regel |
|---|---|
| `schema` | `qm.opt-census-prescreen-declaration/v1` |
| `decision_id` | `OWNER-DEC-PRESCREEN-OHLC-20260911` |
| `program_id`, `base_plan_sha256` | exakte Programm- und Planbindung |
| `candidate_unit` | `pattern_direction_arm_year_bundle` |
| `universe_path`, `universe_sha256`, `candidate_count` | vollständige, vor Ergebniszugriff gebundene Menge |
| `prescreen_model` | `1` |
| `evidence_class` / Abschluss | `PRESCREEN` / `PRESCREEN_MEASURED`; niemals `MEASURED` |
| `ranking_metric` | vorregistrierter DEV-Aggregatwert; kein Pooling von DEV/OOS oder Jahren |
| `keep_fraction` | `0.70`; `ceil` auf Bündel, alle Cutoff-Ties behalten |
| `mandatory_keep_roles` | Baseline, Elternarm, Pflichtkontrollen, Plateau-Nachbarn, Abhängigkeiten |
| `control_fraction_of_drops` | `0.10`; `ceil` je Kohorte, Zufall ohne Zurücklegen |
| `control_seed`, `ranking_snapshot_path`, `ranking_snapshot_sha256` | vor Real-Tick-Kontrollergebnissen gebunden |
| `real_tick_model` | `4`; einzige Quelle für Auswahl, Verdict, Counter und Buch |
| `declared_trial_count` | unverändert 154 plus bereits versiegelte numerische Trials; keine Reduktion durch Drops |
| `fn_definition`, `fn_numerator`, `fn_denominator` | feste Real-Eignungsregel, gewichtete Schätzung, `UNKNOWN` bei leerem Nenner |
| `suspend_above_fn` | strikt `0.10`; zusätzlich Drop-Kontrolltreffer >0.10 |
| `state` | `DECLARED`, `PRESCREENING`, `CONFIRMING`, `SUSPENDED` oder `COMPLETE` |
| `amendment_event` | Zeit, Akteur, vorheriger Ledger-Hash, neuer Ledger-Hash; append-only |

Der Plantext in §2 „Messmatrix“ bleibt für die wissenschaftliche Real-Tick-Matrix
inhaltlich unverändert. Ergänzt wird nur: „Eine nach Nachtrag D zulässige
Vorsortierung erzeugt eine eigene PRESCREEN-Matrix. Nicht bestätigte PRESCREEN-Zellen
sind keine fehlenden `MEASURED`-Zellen; nur die vorregistrierten Keep-, Pflicht- und
Kontrollbündel bilden die Real-Tick-Bestätigungskohorte. Die Auswahlregel wird
ausschließlich auf deren authentifizierter Model-4-Evidenz ausgeführt.“

In §3 wird vor OPT-S2 ein neuer Schritt `OPT-S1b (Fabrik) — PRESCREEN` eingefügt.
OPT-S2 wird zu „Real-Tick-Bestätigung der versiegelten Keep-/Pflicht-/Kontrollkohorte“.
OPT-S3 muss vor Auswertung `prescreen_model == 1`, `evidence_class == PRESCREEN` aus
allen Auswahl-, DSR-, PBO-, Verdict-, Counter- und Buch-Abfragen ausschließen.

## 3. Pilotbindung und Startparameter

Der Pilot zeigt für OHLC-M1 eine Rangkorrelation von 0,977 (n=19, gepoolte
Diagnostik) beziehungsweise 0,952 (2021, n=10). Bei 70% Keep wurden in diesen
kleinen Diagnoseschnitten 0/13 beziehungsweise 0/7 Top-k-False-Negatives beobachtet;
bei 50% Keep reichte die Spanne bereits von 0% bis 20%. Deshalb ist 70% der
konservative Startwert, nicht ein Nachweis, dass die Populations-FNR ≤10% ist.
Der Median der 19 vergleichbaren OHLC-M1-Läufe beträgt 42,678 Tester-Sekunden; der
genannte 132-Sekunden-Real-Tick-Wert ist nur eine einzelne Referenz. Ein positiver
Netto-Walltime-Effekt ist damit noch nicht bewiesen.

## 4. Zahlen — ursprüngliches Szenario und Live-Snapshot

Reine Zellarithmetik ohne Pflichtausnahmen lautet bei N Zellen:
`real = N × [0.70 + 0.10 × 0.30] = 0.73N`, `saved = 0.27N`.
Die produktive Implementierung rundet jedoch auf ganze Arm-Jahresbündel und behält
Pflichtrollen/Ties; daher sind die folgenden Einsparungen Obergrenzen.

| Basis | Pending | billige PRESCREEN-Zellen | Real-Tick-Bestätigungen | Real-Tick-Zellen brutto gespart | brutto gesparte Flottenstunden @45–50/h | PRESCREEN-Zeit T11 @40/h | T11+T12 @je 40/h |
|---|---:|---:|---:|---:|---:|---:|---:|
| Task-Szenario | 6.400 | 6.400 | 4.672 | 1.728 | 34,56–38,40 h | 160,00 h | 80,00 h |
| Read-only Snapshot 2026-09-12 06:25Z | 4.579 | 4.579 | 3.355* | 1.224* | 24,48–27,20 h | 114,48 h | 57,24 h |

`*` Programweise auf Zellebene gerechnet: Keep und 10%-Kontrolle jeweils aufgerundet.
Die echte Bündel-/Pflichtrechnung kann nur weniger sparen. Die Forschungsseat-Zeit
ist keine Flottenstunde und darf nicht von der Bruttoersparnis abgezogen oder mit ihr
addiert werden. T12 ist hier eine Planannahme aus dem OWNER-Entscheid, keine in diesem
Task neu gemessene Durchsatzrate. Wenn PRESCREEN nicht parallel auf freier Kapazität
läuft, ist ein Netto-Walltime-Gewinn aus den vorliegenden Messungen nicht gezeigt.

### Pending je Programm (read-only, 2026-09-12 06:25Z)

| Programm | Pending / cheap | Keep 70% | Drop | Kontrolle 10% Drop | Real bestätigt | Real gespart |
|---|---:|---:|---:|---:|---:|---:|
| `DL089_QM5_10145_XAUUSD_DWX_2019_2025` | 246 | 173 | 73 | 8 | 181 | 65 |
| `DL089_QM5_10403_XAUUSD_DWX_2019_2025` | 286 | 201 | 85 | 9 | 210 | 76 |
| `DL089_QM5_10513_XAUUSD_DWX_2019_2025` | 50 | 35 | 15 | 2 | 37 | 13 |
| `DL089_QM5_10706_GBPUSD_DWX_2019_2025` | 650 | 455 | 195 | 20 | 475 | 175 |
| `DL089_QM5_11422_USDCAD_DWX_2019_2025` | 490 | 343 | 147 | 15 | 358 | 132 |
| `DL089_QM5_11660_NDX_DWX_2019_2025` | 626 | 439 | 187 | 19 | 458 | 168 |
| `DL089_QM5_11881_GBPUSD_DWX_2019_2025` | 655 | 459 | 196 | 20 | 479 | 176 |
| `DL089_QM5_12710_XTIUSD_DWX_2019_2025` | 83 | 59 | 24 | 3 | 62 | 21 |
| `DL089_QM5_13013_NDX_DWX_2019_2025` | 198 | 139 | 59 | 6 | 145 | 53 |
| `DL089_QM5_13213_USDJPY_DWX_2019_2025` | 883 | 619 | 264 | 27 | 646 | 237 |
| `DL089_QM5_20266_XTIUSD_DWX_2019_2025` | 146 | 103 | 43 | 5 | 108 | 38 |
| `DL089_QM5_21507_XAUUSD_DWX_2019_2025` | 48 | 34 | 14 | 2 | 36 | 12 |
| `DL089_QM5_41097_USDJPY_DWX_2019_2025` | 218 | 153 | 65 | 7 | 160 | 58 |
| **Summe** | **4.579** | **3.212** | **1.367** | **143** | **3.355** | **1.224** |

### Counterpfad

PRESCREEN selbst erzeugt keinen Q14-Abschluss und keinen Counter-Punkt. Unter der
rein rechnerischen Annahme, dass die billige Stufe außerhalb des Engpasspfads fertig
ist, geben die kleinsten Restprogramme zuerst Real-Tick-Kapazität frei:
`QM5_21507` (48), `QM5_10513` (50), `QM5_12710` (83), `QM5_20266` (146),
`QM5_13013` (198), `QM5_41097` (218). Nur deren späterer vollständiger Model-4-Pfad
über DL-089-Auswahl, Gesamttest und unveränderte Q14-Gates kann den Counter erreichen.
Eine frühere Q14-Zeit oder ein zusätzlicher Erfolg ist **nicht gezeigt**; fehlende
PRESCREEN-Vorbereitung, Bündelpflichten oder die FN-Sperre können den Vorteil aufheben.

## 5. Rollback und Unveränderliches

- Sofortige logische Sperre neuer PRESCREEN-Claims; laufende sichere Tests dürfen enden.
- Alle Drops append-only als normale Model-4-Anforderungen wieder zulassen.
- PRESCREEN- und Ranking-Evidenz erhalten; keine Umdeklaration zu `MEASURED`.
- `declared_trial_count`, Auswahlregel, DSR/PBO, Q14–Q16 und beide Buchregeln bleiben gleich.
- Kein T_Live/FTMO, kein AutoTrading-Schalter, keine manuelle Terminal-Aktion.
- Erhöhung oder Absenkung von 70% Keep benötigt einen neuen OWNER-Entscheid.

## 6. Deutsche OWNER-Karte — exakt 15 Zeilen

1. DL-089 erhält optional eine vorregistrierte OHLC-M1-Vorsortierung mit MT5 Model=1.
2. Der Startwert behält 70% der vollständigen Pattern×Richtung-Jahresbündel.
3. Zusätzlich werden 10% der verworfenen Bündel zufällig und vollständig kontrolliert.
4. Baseline, Elternarm, Pflichtkontrollen, Plateau-Nachbarn und Abhängigkeiten bleiben immer.
5. PRESCREEN darf nur ordnen oder verkleinern; es ist niemals MEASURED-Evidenz.
6. Nur Real Ticks mit Model=4 dürfen Auswahl, Verdict, DSR, PBO, Counter oder Buch speisen.
7. Die versiegelte Regel ≥2/3 Jahre und ≥+5% bleibt unverändert.
8. Der deklarierte Trial-Raum von 154 plus numerische Trials wird nicht verkleinert.
9. Cutoff, Universum, Seed und Ranking-Snapshot werden vor Ergebnissen gehasht.
10. Über 10% False Negatives oder Kontrolltreffer sperren neue Admissions sofort.
11. UNKNOWN, fehlende Evidenz oder Identitätsbruch sperrt ebenfalls fail-closed.
12. Rollback stellt alle Drops append-only in den normalen Real-Tick-Pfad zurück.
13. PRESCREEN erzeugt selbst keinen Q14-Abschluss und keinen Counter-Punkt.
14. Dieser Entwurf startet nichts, schreibt keine Queue-Zeile und berührt T_Live nie.
15. **OWNER unterschreibt: „Ich genehmige DL-089 Nachtrag D gemäß OWNER-DEC-PRESCREEN-OHLC-20260911.“**
