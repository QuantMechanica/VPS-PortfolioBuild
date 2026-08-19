# OPTIMIZER_TRACK_STATUS — was existiert, was nicht existiert, und woher die 12 % kommen

**Stand:** 2026-08-19 · Work Order Q14–Q16 §1 und §2
**Die Spur bleibt angehalten.** Nichts hiervon ist ausgeführt.

---

## 0 · Eine Prämisse der Work Order trifft nicht zu

> **Es gibt keine von mir programmierten Unger-Filter.** Ich habe im Repo nichts, was diesem
> Begriff entspricht, und ich habe auch keinen Auftrag dazu ausgeführt.
>
> **Und die 12-%-Schwelle sperrt nicht 25 von 25 aus.** Sie gilt nur für **einen von zwei**
> Optimierungshebeln; der andere hat gar keine Drawdown-Bedingung. Fünf Kandidaten haben die
> 12-%-Schwelle bestanden.

Beides gehört korrigiert, bevor eine Runde darauf aufbaut.

---

## 1 · Was mit „Unger" im Bestand existiert — §1.2

**[MESSUNG]** Eine Suche über `framework/`, `tools/`, alle `.mq5`, `.mqh`, `.py`:

| Fund | Art |
|---|---|
| `framework/EAs/QM5_1061_unger-larry-williams-vola-breakout` … `QM5_1107_unger-nasdaq-3pm-breakout` | **EAs**, also Strategien nach Unger-Vorlagen — Vola-Breakout, ORB Index, Bollinger-FX-Mean-Reversion, Inside-Day-Bias DAX, Friday-Close-Reversal, Donchian, Gold-Intraday-Bias, SP500-Pivot, Nasdaq-Pullback |
| `PRODUCTION_DOCTRINE.md` V1 / V2 / V3 | **Vorschläge in einem Dokument** — Frequenz, Cross-Market, Plateau |
| irgendein Filter-Code | **nicht vorhanden** |

**Die V1–V3 sind Vorfilter-Vorschläge, kein Code.** Sie stehen in `PRODUCTION_DOCTRINE.md` §3 als
Erwartung mit Widerlegungskriterium und sind nie implementiert worden — was dort auch so steht
(*„Nicht, dass V1–V3 die Ausbeute sicher heben. Die Erwartung in §3 ist eine Schätzung mit
Widerlegungskriterium, keine Messung."*).

**Und selbst wenn sie implementiert wären, wären sie keine Hebel im Sinne von Q14–Q16:** V1
(Frequenz) und V2 (Cross-Market) sind **Vorfilter vor dem Bau**, V3 (Plateau) ist eine
**Auswertung nach Q08**. Keiner davon verändert einen EA — sie entscheiden, welcher EA überhaupt
entsteht oder weiterläuft. Das gehört, wie die Work Order selbst vorgibt, in einen anderen Teil der
Fabrik.

**Was tatsächlich als Optimierungshebel existiert**, aus den Q14-Verdikten:

| Hebel | Zulassungsregel | zugelassene Kandidaten |
|---|---|---:|
| **EXIT-SURGERY** | `TRADES_GTE_60` | **6** |
| **VOL-REGIME-FILTER** | `TRADES_GTE_150_AND_MAX_DRAWDOWN_GTE_12` | **5** |

Der zweite ist ein **Einstiegsfilter** (Volatilitätsregime) und damit genau die Hebelklasse, für die
§4.4 und §5.1 der Work Order gelten: er verändert, *wann* gehandelt wird, senkt damit die Frequenz
und ändert mit hoher Wahrscheinlichkeit auch das Verhalten um Nachrichten.

## 2 · `OPTIMIZER_RETARGET.md` — Inhalt, §1.1

Das Dokument existiert seit heute 09:24 und wurde nie berichtet. Kern:

**Zwei Prämissen der damaligen Work Order wurden widerlegt.** „0 von 25 zulässig" war falsch — in
der Datenbank stehen **11 `OPT_ELIGIBLE`** gegen 3 `OPT_REJECTED`. Und die Populationsspanne
1,18–9,81 % ist bis heute unbelegt (E-1 / OQ-1); sie kann nicht aus `ea_metrics` stammen, weil
Q14/Q15 dort keinen Drawdown führen.

**Was stattdessen gemessen wurde**, aus 315 Q05-Evidenzdateien: `dd_pct` Median **15,52 %**,
p90 51,0 %, **55,9 % der Kandidaten ≥ 12 %**. Bei 1 % Risiko je Trade ist ein Drawdown ≥ 12 % also
Routine — mit dem selbst angebrachten Vorbehalt, dass Q05 die Stressstufe ist.

**Die Diagnose des Dokuments:** der DD-Hebel ist *nicht leer, sondern falsch angesetzt* — er sucht
hohe Drawdowns hinter fünf Gates, die hohe Drawdowns entfernen. Eine Reihenfolgefrage, keine
Schwellenfrage.

**Die drei damaligen Hebelvorschläge, und was die neue Zielgröße mit ihnen macht:**

| Vorschlag | Status unter „Rendite/Drawdown" |
|---|---|
| **H1 · Ko-Exzedenz-Minimierung** statt Einzel-Drawdown | **überholt als Zielgröße**, bleibt gültig als *Buchkonstruktions*-Kriterium. Er optimiert das Buch, nicht den EA — gehört nach `BOOK_CONSTRUCTION_RULES.md` |
| **H2 · Frequenz-Anhebung** für die 24 buchuntauglichen Paare | **unverändert gültig und jetzt wichtiger.** Er ist der einzige Vorschlag, der auf bereits gate-geprüfte Ware wirkt — und er läuft der Frequenz-Nebenbedingung aus §5.1 **entgegengesetzt**, hebt sie also statt sie zu gefährden |
| **H3 · Sizing als Optimierungsgröße** | **überholt.** Rendite/Drawdown ist skaleninvariant (§3) — ein Sizing-Optimierer kann den Quotienten nicht bewegen |

> **H3 fällt durch die neue Zielgröße rechnerisch weg, H1 wandert in die Buchkonstruktion, H2
> bleibt.** Das ist die Antwort auf §1.1: von drei Vorschlägen überlebt einer, und er ist der, den
> das Dokument ohnehin zuerst empfohlen hat.

## 3 · Die 12-%-Schwelle — §2

### 3.1 Fundstelle und Wortlaut

Sie steht **nicht im Code**, sondern als Begründungstext in den Q14-Verdikten selbst:

```
reason: TRADES_GTE_150_AND_MAX_DRAWDOWN_GTE_12     (VOL-REGIME-FILTER, 5x OPT_ELIGIBLE)
reason: TRADES_GTE_60                              (EXIT-SURGERY,      6x OPT_ELIGIBLE)
reason: MAX_DRAWDOWN_BELOW_12                      (3x OPT_REJECTED)
```

Ein Modul, das diese Regel implementiert, ist im Repo nicht auffindbar — weder in
`q12_optimize_runner.py` (der ausdrücklich *„intentionally outside the canonical pipeline state
machine"* steht) noch in `optimization_dashboard_status.py`, das die Verdikte nur anzeigt.
**Die Regel existiert als Verdikt-Text, nicht als Code.**

### 3.2 Die Prämisse „sperrt 25 von 25 aus" ist falsch

**[MESSUNG]** Alle 14 Q14-Zeilen, vom 13.08.:

| Verdikt | Zahl | Symbole |
|---|---:|---|
| `OPT_ELIGIBLE` (EXIT-SURGERY) | 6 | USDJPY, GBPUSD, NDX, GDAXI ×2, USDCAD |
| `OPT_ELIGIBLE` (VOL-REGIME-FILTER) | 5 | USDJPY, GBPUSD, NDX, GDAXI ×2 |
| `OPT_REJECTED` | 3 | **XAUUSD ×3** (10128, 10145, 10183) |

**Fünf Kandidaten haben die 12-%-Schwelle bestanden.** Abgewiesen wurden drei, alle auf XAUUSD, und
alle mit `MAX_DRAWDOWN_BELOW_12`. Die Schwelle ist also **wirksam, aber nicht sperrend** — und sie
trifft ausgerechnet die Symbolgruppe, die nach `SYMBOL_RANKING_PAIRED.md` die beste ist.

### 3.3 Die Skaleninvarianz — §2.1, geprüft

**[MESSUNG]** Sechs Sleeve-Streams, P&L je Trade mit k ∈ {0,5; 1,0; 2,0; 3,0} skaliert, Quotient
Endergebnis / maximaler Drawdown:

| Sleeve | k=0,5 | k=1,0 | k=2,0 | k=3,0 |
|---|---:|---:|---:|---:|
| 10038 XAUUSD | −0,3677 | −0,3677 | −0,3677 | −0,3677 |
| 10094 GDAXI | 2,6290 | 2,6290 | 2,6290 | 2,6290 |
| 10115 GDAXI | 2,0228 | 2,0228 | 2,0228 | 2,0228 |
| 10122 NDX | −1,0000 | −1,0000 | −1,0000 | −1,0000 |
| 10123 EURNZD | 0,3270 | 0,3270 | 0,3270 | 0,3270 |

**Invariant bis auf Maschinengenauigkeit** — wie das Argument der Work Order es vorhersagt.

**Die Einschränkung, die ich selbst anbringe und die den Beweis begrenzt:** dieser Test skaliert
den **aufgezeichneten Stream**, nicht die **Ausführung**. Er zeigt die arithmetische Invarianz, die
trivial ist, sobald jede Position proportional skaliert. Was er *nicht* zeigt: ob ein echter Lauf
bei anderem Risiko proportionale Positionen erzeugt. Dort greifen **Lot-Quantisierung** (Schritt
0,01), **Mindestlot** und **Margin** — bei kleinem Risiko klemmt die Losgröße am Mindestlot und die
Proportionalität bricht. Der saubere Nachweis wäre ein Doppellauf desselben EA bei 1 % und 3 %
Risiko; er kostet Fabrikzeit und ist nicht gelaufen.

**Fazit trotzdem eindeutig genug:** im relevanten Bereich ist Rendite/Drawdown skaleninvariant, und
damit **kann eine Drawdown-Höhenschwelle die Zielgröße nicht rauschärmer machen.** Sie ist ein
Selektions-, kein Messkriterium — und sie selektiert an der Zielgröße vorbei.

### 3.4 Vorschlag für die Ersatzbedingung — §2.3

Die echte Rauschquelle ist ein Quotient, dessen Nenner auf **einem einzigen** Drawdown-Ereignis
beruht. Dagegen hilft keine Tiefenschwelle, sondern eine Anzahl.

> **Vorschlag: mindestens 5 unabhängige Drawdown-Episoden, definiert als Rückgänge von einem
> Equity-Hoch um ≥ 25 % des maximalen Drawdowns, getrennt durch die Rückkehr auf ein neues Hoch.**

**Wie viele der Kandidaten sie erfüllen würden, habe ich noch nicht gerechnet** — dafür braucht es
die Equity-Kurven der Kandidatenkohorte, und die Kohorte ist nach der OWNER-Entscheidung
(„alle Q09-PASS") gerade neu definiert worden und faktisch leer. **Ich liefere die Zahl, sobald die
Kohorte steht**; ohne sie wäre der Vorschlag genau der Fehler, den die 12-%-Schwelle gemacht hat —
eine Bedingung ohne Prüfung gegen die Population, die sie filtern soll.

**Die bestehende Mindest-Trade-Zahl von 150 reicht dafür nicht:** 150 Trades können in zwei
Drawdown-Episoden liegen oder in dreißig. Die Trade-Zahl misst Aktivität, nicht die Stabilität des
Nenners.

### 3.5 Welches Drawdown-Maß — §2.4

**Ungeklärt, und das ist ein Blocker für die Zielgröße.** `OQ-14` hat gezeigt, dass `drawdown_pct`
je Phase Verschiedenes bedeutet. Die Kandidaten:

| Maß | Quelle | Eigenschaft |
|---|---|---|
| realisierter Max-DD auf der Trade-Reihe | Sleeve-Streams | direkt, aber ein einziges Ereignis |
| `dd_pct` aus der Q05-Evidenz | Stressstufe | härter als Normalbetrieb (Median 15,5 %) |
| Max über die Q04-Folds | Walk-Forward | mehrere Episoden, aber je Fold kürzere Reihe |
| MC-p95 | Monte-Carlo | robuster Nenner, aber ein modelliertes Maß |

**Meine Empfehlung: der realisierte Max-DD auf der vollständigen Trade-Reihe, zusammen mit der
Episodenzahl aus §3.4 als Gültigkeitsbedingung.** Begründung: er ist das einzige Maß, das
unmittelbar aus dem Stream folgt, für alle Kandidaten gleich definiert ist und keine
Phasenabhängigkeit trägt. Die Schwäche — ein einziges Ereignis — wird genau von der Episodenzahl
abgefangen, statt von einer Tiefenschwelle.

**Nicht gesetzt.** Die Wahl des Nenners der Zielgröße ist ein Kontraktkriterium.
