# OPTIMIZER_RETARGET — der DD-Hebel ist nicht leer, er zielt auf die falsche Kohorte

**Snapshot:** `3472a5d2e1b5` · **Stand:** 2026-08-19 · Work Order Runde 7 §5
**Die Spur bleibt angehalten.** Nichts hiervon ist ausgeführt.

---

## 1 · Die Prämisse hält der Messung nicht stand — in zwei Punkten

Die Work Order stellt fest: *„0 von 25 Survivorn für den DD-Hebel zulässig"* und *„der DD-Hebel
verlangt ≥ 12 % Max-DD bei einer Population zwischen 1,18 und 9,81 % — er hat konstruktionsbedingt
keine Angriffsfläche."*

**Beides ist so nicht haltbar.**

**Erstens, die Zulassungszahl.** In der Datenbank stehen für Q14:

| Verdikt | Zeilen |
|---|---:|
| **`OPT_ELIGIBLE`** | **11** |
| `OPT_REJECTED` | 3 |

**Elf zugelassen, nicht null.** Q15 hat genau einen `CHALLENGER_SPAWNED` — der eine erzeugte
Herausforderer aus der Bilanz. Q16 existiert in `work_items` nicht.

**Zweitens, die Population.** Die Spanne 1,18–9,81 % ist genau die Zahl, deren Herkunft seit
Runde 1 als **E-1 / OQ-1 offen** ist: sie kann nicht aus `ea_metrics` stammen, weil Q14/Q15 dort
keinen einzigen Drawdown-Wert führen. Sie ist bis heute unbelegt, und ich baue kein Argument darauf.

**Was ich stattdessen messen kann**, aus 315 gelesenen Q05-Evidenzdateien:

| | |
|---|---|
| beobachteter `dd_pct` | Minimum 0,00 · **Median 15,52** · p90 51,01 · Maximum 140,31 |
| Anteil ≥ 12 % | **176 von 315 = 55,9 %** |
| in der Evidenz hinterlegte Obergrenze `dd_ceiling_pct` | **25,0** |

**Bei 1 % Risiko je Trade erreichen also mehr als die Hälfte der Kandidaten ≥ 12 % Drawdown** — die
Frage aus §5.1 ist damit beantwortet: **ja, das ist erreichbar, und zwar routinemäßig.**

*Einschränkung, die ich selbst anbringe:* Q05 ist die **Stressstufe**, ihre Drawdowns sind
konstruktionsbedingt härter als ein Normallauf. Der Median von 15,5 % ist deshalb keine Aussage über
den Normalbetrieb. Er widerlegt aber die Behauptung, ≥ 12 % sei bei fixem 1-%-Risiko strukturell
unerreichbar.

## 2 · Was wirklich zutrifft

Der Hebel ist **nicht leer, er ist falsch angesetzt.** Er wird auf die **Survivor-Kohorte** angewandt
— eine Population, die vorher durch Q04, Q05, Q06, Q07 und Q08 gelaufen ist und dabei genau die
hochvolatilen Kandidaten verloren hat. Was dort ankommt, hat naturgemäß niedrigen Drawdown.

> **Ein Hebel, der hohe Drawdowns sucht, greift hinter den Filtern, die hohe Drawdowns entfernen.**

Das ist eine Reihenfolgefrage, keine Schwellenfrage — und deshalb ist Absenken der Schwelle die
falsche Antwort.

## 3 · Was die Spur stattdessen optimieren sollte

Die Auditserie hat die bindende Größe benannt, und es ist weder Rendite noch Drawdown:

* `EV_FUNDED_ACCOUNT.md`: nach der Finanzierung zählt allein die **Überlebensdauer**, und die hängt
  an der **Bruchrate**.
* rev2/rev6: die Bruchrate hängt an der **gemeinsamen Tagesamplitude** — der Ko-Exzedenz, nicht am
  Einzel-Drawdown eines Sleeves.
* `SUPPLY_TARGET.md`: die Auszahlung sättigt ab ~12 Sleeves, die **Finanzierungsrate** nicht.

**Drei Hebelvorschläge, je mit vorab formuliertem Widerlegungskriterium:**

### H1 · Ko-Exzedenz-Minimierung statt Einzel-Drawdown

**Hypothese:** ein Sleeve, dessen schlechteste Tage *nicht* mit denen des Bestands zusammenfallen,
senkt die gemeinsame Tagesamplitude stärker, als sein eigener Drawdown erwarten lässt.
**Zielgröße:** Beitrag zum schlechtesten gemeinsamen Tag, nicht eigener Max-DD.
**Widerlegt, wenn:** die Rangfolge nach Ko-Exzedenz-Beitrag nicht besser mit der gemessenen
Bruchrate korreliert als die Rangfolge nach eigenem Drawdown. Prüfbar an den 21 Sleeves, ohne neue
Läufe.

### H2 · Frequenz-Anhebung als Buchtauglichkeits-Hebel

**Hypothese:** die 24 Paare mit 7–30 Trades/Jahr (`FUNNEL_DIAGNOSIS.md` §2) sind nicht schlecht,
sondern **zu selten** — eine Parametervariante mit höherer Signalrate macht sie buchtauglich, ohne
die Logik zu ändern.
**Zielgröße:** Trades/Jahr ≥ 31 bei erhaltenem PF.
**Widerlegt, wenn:** jede Frequenzanhebung den PF unter den Q02-Boden drückt — dann ist die
Seltenheit konstitutiv und die Strategie endgültig buchuntauglich.
**Warum das der wertvollste Hebel sein könnte:** er greift auf 24 Paare, die alle Gates bereits
bestanden haben. Das ist fertige Ware hinter einer einzigen Schwelle.

### H3 · Sizing als Optimierungsgröße statt als Konstante

**Hypothese:** `EV_FUNDED_ACCOUNT.md` zeigt eine Ertragsspanne von 66 $ bis 15.555 $
Break-even-Gebühr allein über das Sizing. Ein Optimierer, der **je Sleeve** das ertragsmaximale
Sizing sucht, hebt mehr als jede Parametervariation.
**Widerlegt, wenn:** das ertragsoptimale Sizing über alle Sleeves hinweg identisch ist — dann ist es
eine Buchentscheidung und kein Optimierungsgegenstand.

## 4 · Kohortenbereinigung

Fünf der neun Kohorteneinträge stehen auf Verdikten, die unter dem heutigen Kontrakt nicht mehr so
erteilt würden. **Vorschlag:** streichen, nicht nachziehen — ein nachgezogenes Verdikt aus einer
alten Vertragslage ist schlechter als eine Lücke, weil es aussieht wie eine Messung.

**Nicht ausgeführt.** Kohorteneinträge sind Bestandsartefakte; ihre Streichung gehört in dieselbe
Kategorie wie das Löschen von Verdikten und ist damit nicht-autonom (§3.3).

## 5 · Empfehlung

**Die Spur bleibt angehalten** — aber nicht aus dem Grund, den die Work Order annimmt. Nicht weil
der Hebel leer ist, sondern weil er **hinter den falschen Filtern steht** und auf die **falsche
Zielgröße** optimiert.

**Vorschlag zur Reihenfolge:** H2 zuerst. Er ist der einzige der drei, der auf bereits
gate-geprüfte Ware wirkt, er braucht keine neue Zielgröße im Kontrakt, und sein Widerlegungskriterium
ist in einem einzigen Backtest je Paar zu prüfen.
