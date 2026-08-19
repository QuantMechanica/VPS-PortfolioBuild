# LOWFREQ_CENSUS — wie viel die Fabrik produziert, das die Gates besteht und nie ins Buch kann

**Stand:** 2026-08-19 · Work Order Runde 8 §2
**Quelle:** `farm_state.sqlite` (read-only), Schnittmenge gegen
`artifacts/audit_activity_criterion_20260819.json`

---

## 0 · Die Antwort

> **109 (EA, Symbol)-Paare tragen `PASS_LOWFREQ`, weitere 78 tragen `RETIRED_LOW_FREQ`.
> Von den 109 ist heute genau null im Kandidatenpool** — die Markierung ist faktisch eine
> Sackgasse, kein Near-Miss.
>
> **Und nur vier von ihnen erfüllen das echte 10-pro-Jahr-Kriterium.** Die Lockerung aus §1 holt
> diese Gruppe also **nicht** zurück. Sie ist zu inaktiv für jede Fassung des Kriteriums.

---

## 1 · Bestand

**[MESSUNG]**

| | |
|---|---|
| Zeilen mit `PASS_LOWFREQ` | **130** |
| davon distinkte (EA, Symbol)-Paare | **109** |
| distinkte EAs | **80** |
| Zeilen mit `RETIRED_LOW_FREQ` | 89 → **78** Paare |

**Alle 130 `PASS_LOWFREQ`-Zeilen stehen in Q04.** Kein anderes Gate vergibt die Markierung — sie
ist eine Eigenschaft der Walk-Forward-Auswertung, nicht ein durchgehendes Frequenzurteil.

Zeitliche Verteilung:

| Monat | Zeilen |
|---|---:|
| 2026-06 | 11 |
| 2026-07 | 72 |
| 2026-08 | 47 |

Die Klasse ist **jung und wächst** — sie entsteht seit Juni und macht im laufenden Monat bereits
wieder 47 Zeilen aus. Das ist kein Altbestand, sondern laufende Produktion.

## 2 · Schnittmenge mit dem echten Aktivitätskriterium — §2.2

**[MESSUNG]** Von den 109 Paaren haben 31 einen Q08-Trade-Stream auf Platte (die übrigen sind
nie so weit gekommen).

| | |
|---|---:|
| `PASS_LOWFREQ`-Paare mit Stream | 31 |
| davon heute im Pool (≥ 250 Schlusstage) | **0** |
| davon mit ≥ 10 Handelstagen in **jedem** vollen Jahr | **4** |

Die vier: `10127:AUDUSD`, `10558:EURUSD`, `1230:AUDJPY`, `1230:XAUUSD` — jeweils 7,7 bis 8,1 Jahre
Spanne, 108 bis 200 Schlusstage. Sie erfüllen das Kriterium, stehen aber trotzdem nicht in der
Rückgewinnungsliste aus §1, weil sie an einem Gate oder an der Entry-Coverage scheitern, nicht am
Tagesfilter.

> **Damit ist die Erwartung der Work Order („diese Gruppe ist der eigentliche Fund") widerlegt.**
> `PASS_LOWFREQ` und die 250-Filter-Blockade sind zwei fast disjunkte Mengen: die einen sind zu
> inaktiv für jedes Kriterium, die anderen waren nur zu inaktiv für einen zu strengen Filter.

## 3 · Häufung — §2.3

Nach Anlageklasse:

| Klasse | `PASS_LOWFREQ` | `RETIRED_LOW_FREQ` |
|---|---:|---:|
| **FX** | **48** | **52** |
| Index | 27 | 16 |
| Energie | 19 | 4 |
| Metall | 11 | 6 |
| sonstige | 4 | 0 |

**FX stellt 44 % der `PASS_LOWFREQ`- und 67 % der `RETIRED_LOW_FREQ`-Paare.** Das ist derselbe
Befund wie in `FAMILY_ASSET_MATRIX.md`, von der anderen Seite gesehen: auf FX produziert die
Fabrik nicht nur die meisten Fehlschläge, sondern auch die meisten Strategien, die zwar bestehen,
aber zu selten handeln.

Nach EA-Familie ist die Streuung breit — 109 Paare auf 80 EAs, der größte ID-Block stellt 15. **Es
gibt keine einzelne Familie, deren Reparatur die Klasse auflöst.** Das entspricht dem Befund aus
`FUNNEL_DIAGNOSIS.md` §3: die Ablehnungen sind individuell, nicht systematisch.

## 4 · Was daraus für die Produktion folgt — §2.4

**Die Klasse ist eine Generierungsvorgabe, keine Filterfrage.** Belege dafür, in dieser Reihenfolge:

1. Null von 109 sind heute buchfähig — die Markierung führt nirgendwo hin.
2. Nur vier erfüllen das echte Kriterium — eine Filterlockerung rettet sie nicht.
3. Die Klasse wächst monatlich weiter.

Damit ist jede `PASS_LOWFREQ`-Zeile **verbrauchte Fabrikzeit ohne Ertragsaussicht**: Q02, Q03 und
Q04 sind gelaufen und bezahlt, und das Ergebnis ist per Konstruktion nicht verwertbar.

**Vorschlag für `PRODUCTION_DOCTRINE.md`** — als Vorgabe an die Erzeugung, nicht als Gate:

> Eine Strategiekarte, deren erwartete Handelsfrequenz unter etwa 30 Trades pro Jahr und Symbol
> liegt, wird nicht gebaut. Das ist keine Qualitätsaussage — es ist die Feststellung, dass die
> Buchaufnahme eine Aktivitätsdichte verlangt, die eine solche Karte nicht erreichen kann.

**Was das nicht sagt:** dass der Q02-Frequenzboden (≥ 5 Trades/Jahr) falsch ist. Der ist eine
Ökonomiegrenze und liegt korrekt. Die Lücke zwischen 5 und der Buchfähigkeit ist der Punkt — und
sie wird an der Erzeugung geschlossen, nicht an einer Schwelle.
