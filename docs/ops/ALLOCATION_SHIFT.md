# ALLOCATION_SHIFT — wo die Symbolzuteilung entsteht und was ihre Korrektur wert ist

**Stand:** 2026-08-19 · Work Order Runde 9 §2
**Quellen:** `farmctl.py:17402–17540`, `framework/registry/dwx_symbol_matrix.csv`,
`farm_state.sqlite` (read-only), `FAMILY_ASSET_MATRIX.md`

---

## 0 · Die Antwort

> **Die Zuteilung ist keine Entscheidung, sondern ein Nebeneffekt.** Das Symbolregister enthält
> 37 Symbole, davon **28 FX (75,7 %)**, und eine Karte ohne erklärtes Universum wird über *alle*
> 37 aufgefächert. Niemand hat je beschlossen, 56 % der Kapazität auf FX zu fahren — es ist die
> Form des Registers, multipliziert mit einem „nimm alles"-Rückfall.
>
> **Aber der größere Anteil liegt woanders:** 663 Karten *erklären* ihr Universum, und sie
> erklären es fast durchweg FX-zuerst. Die Zuteilung ist damit **überwiegend eine
> Autorengewohnheit**, kein Konfigurationsfehler.

---

## 1 · Wo sie entsteht — die Kette, belegt

`farmctl.py:17532`:

```python
def _p2_target_symbols_for_ea(root, ea_id):
    declared = _card_declared_universe_for_ea(root, ea_id)   # 1. Karte
    if declared:
        return sorted(declared)
    if _card_single_symbol_only(root, ea_id):                # 2. Einzelsymbol-Marke
        return [symbol for symbol, _ in _find_ea_setfiles(ea_id, "P2")]
    return _dwx_backtest_symbols()                           # 3. ALLES
```

Drei Stufen, und die dritte ist das ganze Register:

| Stufe | Quelle | Wirkung |
|---|---|---|
| 1 | `target_symbols` im Frontmatter der Strategiekarte | maßgeblich, wenn vorhanden |
| 2 | `single_symbol_only`-Marke | begrenzt auf vorhandene Setfiles |
| 3 | **`_dwx_backtest_symbols()`** → `framework/registry/dwx_symbol_matrix.csv` | **alle 37 Symbole** |

**[MESSUNG] Das Register, nach Anlageklasse:**

| Klasse | Symbole | Anteil |
|---|---:|---:|
| **FX** | **28** | **75,7 %** |
| Index | 5 | 13,5 % |
| Metall | 2 | 5,4 % |
| Energie | 2 | 5,4 % |

Ein EA ohne Kartenuniversum wird also auf 28 FX-Paare und 2 Metalle gefächert — bei
Durchlassquoten von 3,9 % gegen 20,3 %.

### 1.1 Wie viel davon der Rückfall ist, und wie viel die Karten

**[MESSUNG]** Auffächerung je EA über alle Work Items:

| Symbole je EA | EAs |
|---|---:|
| 1 | 764 |
| 2–7 | 1.839 |
| **genau 37** | **75** ← der Rückfall auf das ganze Register |

Median 4, Mittel 4,89. **75 EAs sind über das volle Register gelaufen** — das sind 2.775 Paare,
rund 19 % aller 14.358.

Die übrigen ~81 % stammen aus **663 Karten mit erklärtem Universum**, und deren Erklärungen sehen
so aus:

```
[EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX]
[EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
[AUDUSD.DWX, NZDUSD.DWX, USDCAD.DWX]
[AUDUSD.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX]
```

> **Das ist der eigentliche Befund von §2.1: der Hebel liegt nicht an einer Stellschraube, sondern
> an einer Gewohnheit.** Wer eine Karte schreibt, nennt die Majors. Ein Fix am Rückfall erreicht
> 19 % der Paare; die restlichen 81 % erreicht nur eine Vorgabe an die Kartenerstellung.

---

## 2 · Die dritte Leitplanke zuerst — und sie verändert den Vorschlag

Die Work Order verlangt zu prüfen, ob die Klassenordnung auch auf **Buchtauglichkeit** gilt und
nicht nur auf Q04-PASS. Sie tut es — aber schwächer, und der Unterschied ist entscheidend.

**[MESSUNG]** Gate-Läufe gegen tatsächliche Buch-Sleeves (die 23 zugelassenen aus
`ACTIVITY_CRITERION.md`):

| Klasse | Gate-Läufe | Gate-Quote | Buch-Sleeves | **Sleeves je 1.000 Läufe** |
|---|---:|---:|---:|---:|
| **Metall** | 1.046 | 35,4 % | 7 | **6,69** |
| Energie | 442 | 22,4 % | 2 | 4,52 |
| Index | 1.891 | 21,7 % | 8 | 4,23 |
| **FX** | 4.608 | 8,2 % | **6** | **1,30** |

**Zwei Ablesungen:**

1. **Die Ordnung bleibt** — Metall führt, FX ist letzter.
2. **Der Abstand schrumpft von 4,3× auf 5,1× … aber FX liefert trotzdem 6 der 23 Sleeves (26 %).**
   Bei 8 % Gate-Quote. FX ist ineffizient, aber es ist **kein Ausfall**: mehr als ein Viertel des
   bestehenden Buchs steht auf FX.

**Und der Index ist der wahre Gewinner nach Volumen:** 8 Sleeves, mehr als Metall, bei einem
Drittel der Metall-Effizienz je Lauf.

> **Konsequenz für den Vorschlag:** FX wird gedrosselt, nicht abgeschaltet. Wer FX auf null
> setzt, verliert ein Viertel der Sleeve-Quellen des Buchs, um eine Effizienzkennzahl zu heben.

---

## 3 · Vorschlag für die neue Verteilung

**Vorbemerkung zur ersten Leitplanke:** das Folgende betrifft **Gate-Läufe**, also worauf die
Terminals ihre Zeit verwenden. Es ist **keine** Aussage über die Zusammensetzung des Buchs; die
regelt `BOOK_CONSTRUCTION_RULES.md` mit eigenen Symbol- und Klassengrenzen. Eine 45-%-Metall-Quote
in der Produktion darf nicht zu einem 45-%-Metall-Buch führen.

| Klasse | heute (Läufe) | **Vorschlag** | Begründung |
|---|---:|---:|---|
| Metall | 12,8 % | **30 %** | höchste Ausbeute je Lauf (6,69/1.000); begrenzt durch nur 2 verfügbare Symbole |
| Index | 23,1 % | **30 %** | zweitbeste Ausbeute, **fünf** Symbole, damit skalierbar ohne Konzentration |
| Energie | 5,4 % | **15 %** | 4,52/1.000 bei nur 442 Läufen — die am wenigsten erforschte Klasse |
| **FX** | **56,4 %** | **25 %** | **Boden, nicht Ziel** — siehe unten |

### 3.1 Der FX-Boden, wie verlangt

> **FX fällt nicht unter 25 % der Gate-Läufe.**

Drei Gründe, in der Reihenfolge ihres Gewichts:

1. **Diversifikation.** FX stellt heute 6 der 23 Buch-Sleeves. Metall (2 Symbole) und Energie
   (2 Symbole) können das nicht ersetzen, und `ACTIVITY_CRITERION.md` §3.1 hat gemessen, was
   Konzentration kostet: fünf XTIUSD-Sleeves auf einmal kosteten zehn Punkte
   Finanzierungswahrscheinlichkeit.
2. **Symbolbreite.** 28 FX-Symbole gegen 2 Metalle. Ein Buch braucht unkorrelierte Quellen; die
   Klasse mit der größten Symbolbreite kann sie am ehesten liefern.
3. **3,9 % ist nicht null.** Bei 25 % von ~21 Zeilen/h sind das immer noch rund 40 FX-Q04-Läufe je
   Tag.

### 3.2 Wie es umgesetzt würde — zwei getrennte Eingriffe

| Eingriff | erreicht | Aufwand |
|---|---|---|
| **A · Rückfall begrenzen:** `_dwx_backtest_symbols()` nicht mehr als „alles", sondern als klassengewichtete Auswahl | 19 % der Paare (die 75 Voll-Fächer-EAs) | eine Funktion |
| **B · Kartenvorgabe:** `target_symbols` muss die Klassenverteilung einhalten; Prüfung bei `approve-card` | 81 % der Paare | Validator + Doktrin-Eintrag |

**B ist der eigentliche Hebel und der langsamere.** A wirkt sofort, aber nur auf ein Fünftel.

**Nichts davon ist umgesetzt.** Beides sind Änderungen an der Einreihungslogik und damit an der
Kandidatenpool-Definition — ausdrücklich nicht-autonom nach §3.3.

---

## 4 · Wirkung auf die 2.291 pendenten Zeilen

**[MESSUNG]** Warteschlange nach Klasse:

| Klasse | pendent | Anteil |
|---|---:|---:|
| **FX** | **1.220** | **53,3 %** |
| Metall | 484 | 21,1 % |
| Index | 452 | 19,7 % |
| sonstige | 71 | 3,1 % |
| Energie | 64 | 2,8 % |

Davon **951 FX-Zeilen in Q04** — dem Gate mit 3,9 % FX-Durchlass.

**Die Rechnung, die die Umsteuerung rechtfertigt:**

| | |
|---|---|
| 951 FX-Q04-Zeilen bei 21 Zeilen/h | **≈ 45 Fabrikstunden** |
| erwartete Bestehende bei 3,9 % | **≈ 37** |
| dieselben 45 Stunden auf Metall bei 20,3 % | **≈ 193** |
| **Differenz** | **≈ 156 zusätzliche Q04-Bestehende für dieselbe Zeit** |

**Was ich damit nicht tue:** die 951 Zeilen streichen. Sie sind eingereiht, ihre EAs haben Q02
bestanden, und ein Teil davon trägt später Buch-Sleeves (FX stellt 26 % des Buchs). Der Vorschlag
betrifft die **Priorisierung** — FX-Q04-Zeilen hinter Metall und Index einordnen, nicht löschen.

---

## 5 · Erfolgskriterium, vorab festgelegt (§2.4)

> **In zwei Wochen, also am 2026-09-02, gilt die Umsteuerung als wirksam, wenn beide Bedingungen
> erfüllt sind:**
>
> 1. **Der FX-Anteil der Robustheitsgate-Läufe liegt zwischen 22 % und 30 %** (heute 56,4 %) —
>    gemessen über die in diesem Zeitraum terminal gewordenen Zeilen, nicht über den Bestand.
> 2. **Die Q04-Gesamtdurchlassquote über alle Klassen liegt über 12 %** (heute 9,1 % laut
>    `FUNNEL_DIAGNOSIS.md`) — bei unveränderten Gate-Schwellen.
>
> **Widerlegt ist sie, wenn** Bedingung 1 erfüllt und Bedingung 2 verfehlt wird. Dann ist der
> Klassenunterschied entweder ein Selektionsartefakt, das der gepaarte Test nicht gefangen hat,
> oder die verschobene Kapazität trifft auf zu wenige Metall- und Index-Kandidaten.

**Die Zahl 12 % ist bewusst niedriger als die naive Hochrechnung.** Bei der vorgeschlagenen
Verteilung ergäbe die Mischung der heutigen Klassenquoten rein rechnerisch ~14 %. Ich setze 12 %,
weil die verfügbare Kandidatenmenge je Klasse begrenzt ist und die Verschiebung nicht in zwei
Wochen vollständig durchschlägt.

**Gegenprobe gegen den offensichtlichen Selbstbetrug:** die Quote ließe sich auch heben, indem man
einfach weniger FX testet und dieselben Metall-Kandidaten mehrfach fährt. Deshalb zählt Bedingung 2
nur **distinkte (EA, Symbol)-Paare**, keine Wiederholungen.
