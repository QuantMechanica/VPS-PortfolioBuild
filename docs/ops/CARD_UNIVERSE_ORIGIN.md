# CARD_UNIVERSE_ORIGIN — woher die Symbolwahl kommt, und der Befund daneben

**Stand:** 2026-08-19 · Work Order Runde 10 §2
**Quelle:** 1.510 Kartendateien (`artifacts/cards_approved`, `framework/EAs/*/docs`, `docs/**`),
`farmctl.py:17532`

---

## 0 · Zwei Antworten, und die zweite stand nicht in der Frage

> **Zur Symbolfrage: meine Behauptung aus Runde 9 war falsch.** Ich hatte geschrieben, die Karten
> nennen „fast durchweg Majors". Gemessen sind von 1.950 genannten Symbolplätzen **44,8 % FX** —
> und das meistgenannte Einzelsymbol ist **XTIUSD** mit 17,3 %, nicht EURUSD. Ich hatte aus vier
> Stichproben verallgemeinert.
>
> **Und der Befund daneben ist größer als die Symbolfrage: 604 von 810 Karten (74,6 %) erklären
> eine Handelsfrequenz unter 31 Trades pro Jahr — dem Buch-Boden. 315 erklären unter 10, also
> unter OWNERs eigenem Aktivitätskriterium.** Der Median liegt bei **12**.
>
> Die Fabrik baut, in großem Maßstab, Strategien, die in ihrer eigenen Spezifikation erklären,
> dass sie nie buchfähig werden können.

---

## 1 · Herkunft — §2.1

**[MESSUNG]** 1.510 Kartendateien gescannt, **864 mit `target_symbols`**.

| `created_by` | Karten |
|---|---:|
| *(kein Feld)* | 542 |
| **Research+Development** | 248 |
| Research | 64 |
| Codex | 6 |
| claude-board-advisor | 2 |
| Claude | 1 |

Die Karten entstehen also in der **Forschungsspur**, nicht von Hand und nicht in der Fabrik. Der
Speicher ist `artifacts/cards_approved` (208 Dateien), gespiegelt in die EA-Verzeichnisse.

**§2.4 — ja, es entstehen laufend neue:**

| Monat | neue Karten |
|---|---:|
| 2026-06 | 1 |
| 2026-07 | 123 |
| **2026-08** | **202** |

> **Eine Vorlagenänderung erreicht rund 200 Karten je Monat.** Das ist genug, um die
> Zusammensetzung des Zuflusses innerhalb weniger Wochen zu drehen — deine Einschätzung in §2 war
> richtig, und dies ist der einzige Eingriff der Serie mit dauerhafter Wirkung.

## 2 · Gibt es ein Template-Feld — §2.2

**Ja, und es ist reichhaltiger als vermutet.** Jede Karte trägt ein festes Frontmatter, hier am
Beispiel `QM5_20203`:

```yaml
markets: [forex]
timeframes: [D1]
primary_target_symbols: [EURUSD.DWX, AUDJPY.DWX]
target_symbols: [EURUSD.DWX, AUDJPY.DWX]
logical_symbol: QM5_20203_EURUSD_AUDJPY_COINTEGRATION_D1
expected_trades_per_year_per_symbol: 5
```

Es gibt also **zwei** Symbolfelder (`primary_target_symbols` und `target_symbols`), ein
`markets`-Feld und — entscheidend für §3 — ein Feld für die erwartete Handelsfrequenz.

## 3 · Aussage oder Gewohnheit — §2.3, und die Antwort ist geteilt

**[MESSUNG]** Von den 864 Karten mit erklärtem Universum:

| Art | Karten | änderbar? |
|---|---:|---|
| **Paar / Basket — die Symbole *sind* die Strategie** | **488 (56 %)** | **nein** |
| einfache Instrumentenliste | **376 (44 %)** | ja |

Die 488 tragen ein `logical_symbol` wie `QM5_20203_EURUSD_AUDJPY_COINTEGRATION_D1` oder Flags wie
`cointegration-pair-trade`, `spread`, `ratio`, `basket`. Bei ihnen ist das Symbolpaar die
Hypothese — eine Änderung würde die Karte nicht anpassen, sondern zerstören.

> **Damit ist §2.3 beantwortet: über die Hälfte der Universen ist eine Strategieaussage und darf
> nicht angefasst werden.** Der Hebel wirkt nur auf die 376 Instrumentenlisten.

**Und die Symbolverteilung erklärt sich daraus:**

| Klasse | genannte Plätze | Anteil |
|---|---:|---:|
| FX | 874 | **44,8 %** |
| **Energie** | 534 | **27,3 %** |
| Index | 274 | 14,0 % |
| Metall | 242 | 12,4 % |

Meistgenannt: **XTIUSD 338 (17,3 %)**, EURUSD 188, XAUUSD 183, GBPUSD 161, XNGUSD 156.

Der hohe Energieanteil kommt fast vollständig aus den Paar-Strategien (`XTI_XNG_*`,
`XTI_XAU_*`) — also aus genau der Gruppe, die nicht änderbar ist. **Die 56 % FX in den
tatsächlichen Gate-Läufen entstehen daher nicht überwiegend aus den Karten**, sondern aus dem
37-Symbol-Rückfall für Karten ohne Universum, kombiniert damit, dass Karten im Median nur **1 bis 2
Symbole** nennen (404 Karten nennen genau eines, 235 genau zwei).

## 4 · Der Befund, der nicht in der Frage stand

**[MESSUNG]** 810 Karten tragen `expected_trades_per_year_per_symbol`:

| | |
|---|---:|
| Median | **12,0** |
| Minimum | 2,0 |
| Maximum | 600,0 |
| **Karten unter 31/Jahr** (Buch-Boden) | **604 (74,6 %)** |
| **Karten unter 10/Jahr** (OWNER-Kriterium) | **315 (38,9 %)** |

Zur Erinnerung die Kette aus `FUNNEL_DIAGNOSIS.md` §2: Q02 lässt ab **5 Trades/Jahr** durch, der
Bucheintritt verlangt ≈ **31**. Karten im Band dazwischen bestehen die Gates und können nie ins
Buch.

> **Drei Viertel der erzeugten Karten deklarieren sich selbst in dieses Band hinein — bevor ein
> einziger Backtest läuft.**

Und die Karten wissen es: `QM5_20203` schreibt wörtlich *„Approximately 5 completed two-leg
packages per year per traded symbol … Q02 must retire the sleeve if realized frequency is below the
binding floor."* Die Karte kennt den Boden, nennt eine Zahl darunter, und wird trotzdem gebaut.

**Das ist die Erklärung für `LOWFREQ_CENSUS.md`**, die dort fehlte: die 109 `PASS_LOWFREQ`- und 78
`RETIRED_LOW_FREQ`-Paare sind kein Messergebnis, sondern die vorhersehbare Folge einer
Kartenerzeugung, die die Buchfähigkeit nicht als Kriterium führt.

**Der Hebel ist eine Zeile in der Kartenprüfung** — und er ist um Größenordnungen billiger als jede
Symbolumverteilung, weil er Bauarbeit vermeidet statt Testzeit umzuschichten.

## 5 · Vorschlag — §2.5, vorgelegt, nicht umgesetzt

**V-A · Frequenzschwelle bei der Kartenannahme.** Eine Karte mit
`expected_trades_per_year_per_symbol < 31` wird nicht gebaut, sondern zurückgewiesen — mit der
Begründung, dass sie den Bucheintritt konstruktiv nicht erreichen kann. Prüfbar in
`approve-card`, kein Gate, keine Schwellenänderung an der Pipeline.

*Erwartete Wirkung:* bei 202 neuen Karten je Monat und 74,6 % unter der Schwelle entfielen rund
**150 Builds monatlich** — Kapazität, die vollständig in buchfähige Kandidaten fließen könnte.

*Zu prüfen, bevor das gilt:* ob die deklarierte Frequenz die realisierte trifft. Die Karte von
`QM5_20203` nennt 5, gemessen wurde bei ähnlichen Paaren 7–30. Eine Schwelle auf einer
unkalibrierten Selbstauskunft wäre wertlos. **Das ist die Messung, die vor V-A steht.**

**V-B · Universum nur für die 376 Instrumentenlisten.** Die Symbolrangfolge aus
`SYMBOL_RANKING_PAIRED.md` als Vorgabe: bevorzugt XAUUSD, WS30, SP500, XAGUSD, NDX; die acht
Nullsymbole und UK100 nicht ohne Begründung. **Die 488 Paar- und Basket-Karten bleiben
unberührt** — dort ist das Symbol die Hypothese.

**V-C · Den 37-Symbol-Rückfall ersetzen.** Karten ohne Universum sollen nicht über alle 37 Symbole
laufen, sondern über die bevorzugte Gruppe. Betrifft die 75 Alles-Läufer und alle künftigen ohne
Erklärung.

**Reihenfolge nach Wirkung je Aufwand: V-A, dann V-C, dann V-B.** V-A ist der einzige Vorschlag,
der Bauarbeit spart statt sie umzuverteilen.

**Nichts umgesetzt.** Kartenuniversen und Annahmekriterien berühren die Kandidatenpool-Definition
und sind nach §3.3 nicht autonom.
