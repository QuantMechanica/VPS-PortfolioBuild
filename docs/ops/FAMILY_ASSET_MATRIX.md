# FAMILY_ASSET_MATRIX — die Anlageklasse trägt, nicht die Familie

**Stand:** 2026-08-19 · Work Order Runde 8 §5.1
**Erzeuger:** `tools/strategy_farm/portfolio/audit_family_asset_matrix.py` ·
Artefakt `artifacts/audit_family_asset_matrix_20260819.json`

---

## 0 · Der Befund, der größer ist als die Frage

Gefragt war, ob die Familie `QM5_215xx` ein Muster zeigt. Sie tut es — aber die Kreuztabelle über
den ganzen Bestand zeigt, dass das Muster **nicht der Familie gehört.**

> **Dieselben EAs bestehen Q04 auf Edelmetall mit 20,3 % und auf FX mit 3,9 %.** Gepaart gemessen,
> 497 EAs, die auf beiden Klassen gelaufen sind — der EA ist konstant gehalten, nur das Symbol
> wechselt.
>
> **Und die Fabrik verbringt 56 % ihrer Robustheits-Gate-Läufe auf FX** — der Klasse mit der
> niedrigsten Quote, um den Faktor fünf.

---

## 1 · Die Grundtabelle

**[MESSUNG]** Letztes Verdikt je (EA, Symbol, Gate), nur Robustheitsgates. Als bestanden zählen
`PASS`, `PASS_SOFT`, `PASS_LOWFREQ`, `MULTI_SEED_PASS`.

| Gate | Metall | Energie | Index | **FX** | sonstige |
|---|---:|---:|---:|---:|---:|
| Q04 | 135/667 **20 %** | 39/342 11 % | 193/1428 14 % | **185/4187 4 %** | 18/116 16 % |
| Q05 | 88/139 63 % | 24/41 59 % | 81/233 35 % | 78/207 38 % | 16/21 76 % |
| Q06 | 80/93 86 % | 19/26 73 % | 74/90 82 % | 67/88 76 % | 15/16 94 % |
| Q07 | 58/85 68 % | 12/20 60 % | 51/79 65 % | 44/73 60 % | 15/16 94 % |
| Q08 | 9/62 15 % | 5/13 38 % | 11/61 18 % | 6/53 11 % | 0/15 0 % |
| **alle** | **370/1046 35 %** | 99/442 22 % | 410/1891 22 % | **380/4608 8 %** | 64/184 35 % |

**Der Schnitt liegt bei Q04**, dem Walk-Forward-Gate: 20 % gegen 4 %. Ab Q05 gleichen sich die
Klassen an — was FX überlebt, ist danach nicht mehr auffällig schlechter. **Der Filter, der FX
tötet, ist die Out-of-Sample-Stabilität, nicht Stress, Nachbarschaft oder Seed-Streuung.**

## 2 · Der gepaarte Test — die Kontrolle, ohne die die Tabelle nichts wert wäre

Die Grundtabelle könnte reine Selektion sein: vielleicht werden auf Metall bessere EAs getestet.
Deshalb der Test bei konstant gehaltenem EA — nur EAs, die auf **beiden** Klassen Q04 gelaufen sind:

| | | |
|---|---:|---:|
| **EAs mit Q04-Läufen auf FX *und* Metall** | **497** | |
| dieselben EAs auf FX | 84/2151 | **3,9 %** |
| dieselben EAs auf Metall | 107/527 | **20,3 %** |
| EAs, bei denen Metall besser abschneidet | **104** | |
| EAs, bei denen FX besser abschneidet | 42 | |
| gleichauf | 351 | |

Und gegen Index, dieselbe Konstruktion, 429 EAs: FX 3,7 %, Index 12,0 %.

**104 zu 42 bei 146 entschiedenen Paaren** ist keine Zufallsverteilung — unter der Nullhypothese
gleicher Schwierigkeit liegt die Wahrscheinlichkeit dieser Aufteilung im Bereich von 10⁻⁷.

> **Der Effekt gehört dem Symbol, nicht dem EA.** Damit fällt die naheliegende Gegenerklärung.

## 3 · Familien mit Anlageklassen-Schnitt

33 Familien haben ≥ 8 Robustheitsgate-Läufe auf mindestens zwei Klassen. Die zwanzig schärfsten
Schnitte:

| Familie | beste Klasse | Quote | n | schlechteste | Quote | n | Abstand |
|---|---|---:|---:|---|---:|---:|---:|
| carver | Metall | 0,70 | 30 | Energie | 0,00 | 10 | 0,70 |
| demark | Metall | 0,69 | 16 | Index | 0,00 | 21 | 0,69 |
| weiss | Metall | 0,59 | 27 | Energie | 0,00 | 9 | 0,59 |
| nnfx | Metall | 0,62 | 8 | FX | 0,04 | 46 | 0,58 |
| don20 | Metall | 0,70 | 10 | FX | 0,16 | 31 | 0,54 |
| tii | Energie | 0,50 | 8 | Index | 0,00 | 9 | 0,50 |
| don | Index | 0,50 | 10 | FX | 0,00 | 28 | 0,50 |
| aa | Metall | 0,50 | 20 | Index | 0,06 | 55 | 0,45 |
| lt | Index | 0,44 | 9 | FX | 0,00 | 9 | 0,44 |
| tmom | Metall | 0,43 | 14 | FX | 0,00 | 27 | 0,43 |
| cinar | Metall | 0,43 | 37 | FX | 0,01 | **374** | 0,42 |
| commodity | Metall | 0,80 | 10 | Energie | 0,46 | 11 | 0,34 |
| ft | Metall | 0,36 | 11 | FX | 0,04 | 26 | 0,33 |
| bb | Metall | 0,40 | 10 | FX | 0,09 | 104 | 0,31 |
| ftmo | Metall | 0,33 | 18 | FX | 0,06 | 54 | 0,28 |
| tv | Metall | 0,27 | **209** | Energie | 0,00 | 9 | 0,27 |
| grimes | Energie | 0,50 | 8 | FX | 0,24 | 50 | 0,26 |
| chande | Index | 0,36 | 11 | FX | 0,11 | 18 | 0,25 |
| wti | sonstige | 0,50 | 14 | Energie | 0,25 | 119 | 0,25 |
| gh | Metall | 0,31 | 16 | FX | 0,07 | 42 | 0,24 |

**In 13 von 20 ist Metall die beste Klasse, in 11 von 20 ist FX die schlechteste.** Die Familien
unterscheiden sich im Niveau, kaum in der Rangfolge der Klassen. `cinar` ist der klarste Fall:
374 FX-Läufe für eine Quote von 1 %, 37 Metall-Läufe für 43 %.

**Antwort auf §5.1: ja, es gibt weitere Familien mit Anlageklassen-Schnitt — aber der Schnitt ist
familienübergreifend derselbe.** Eine Familie als Produktionsvorlage zu wählen greift zu kurz;
die Symbolzuteilung ist der stärkere Hebel.

## 4 · Was das für den Cross-Market-Test bedeutet

Ungers Cross-Market-Validierung verlangt, dass eine Strategie mit unverändertem Parametersatz auf
mehreren Märkten trägt. Auf unseren Daten ist das **innerhalb einer Anlageklasse** ein sinnvoller
Test und **über Anlageklassen hinweg** kein Qualitätsmerkmal, sondern ein Symbolzuteilungsartefakt:
ein EA, der auf XAUUSD und XAGUSD besteht und auf EURUSD scheitert, hat nicht „nur auf zwei von
drei Märkten funktioniert" — er wurde auf einem Markt getestet, den unsere Gates fast niemandem
durchgehen lassen.

**Als Hypothese mit Widerlegungskriterium, wie verlangt:**

> **H:** Die Q04-Quote hängt stärker vom Symbol als vom EA ab, und FX ist strukturell härter.
> **Widerlegt, wenn:** ein Satz FX-Paare mit ≥ 100 Läufen eine Q04-Quote ≥ 15 % erreicht, oder
> wenn der gepaarte Test auf neuen Kohorten unter 2× Unterschied fällt.

## 5 · Der Fall QM5_215xx — noch offen

Die Familie, die den Anlass gab, ist mit dem obigen konsistent (Metall bestanden, Indizes
gescheitert), aber **die Parametersatz-Prüfung aus §5.1.2 steht noch aus** — ob XAUUSD, XAGUSD und
die Indexläufe denselben Parametersatz benutzen. Ohne diese Prüfung ist es kein
Cross-Market-Beleg, sondern eine Familie mit gemeinsamer Herkunft. Wird nachgetragen.

## 6 · Die Konsequenz, die in die Doktrin gehört

**Die Fabrik verbringt 4.608 von 8.171 Robustheitsgate-Läufen (56 %) auf FX und erntet dort 8 %.**
Auf Metall stehen 1.046 Läufe für 35 %. Die Symbolzuteilung ist damit — vor jeder
Strategieverbesserung — der größte einzelne Hebel auf die Ausbeute, den diese Serie gefunden hat.

**Was hier ausdrücklich nicht steht:** dass FX aufgegeben werden soll. Die Zahl sagt, wo die
heutigen Gates Kandidaten durchlassen, nicht wo Ertrag liegt; ein Buch nur aus Metall wäre nach
§1 dieser Runde genau der Konzentrationsfehler, der dort gemessen wurde. Die Vorlage ist eine
Verschiebung der Zuteilung, keine Aufgabe einer Klasse — und sie gehört OWNER vorgelegt, nicht von
mir gesetzt.
