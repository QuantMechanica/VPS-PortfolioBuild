# Audit-Antwort, Revision 6 — Abschluss

**Gilt für Snapshot `3472a5d2e1b5`, Stand 2026-08-18.**
**Änderungsmarkierung gegenüber `audit_rev5.md`.**
Reproduzierbar: `audit_intraday_sizing_sweep.py` · `audit_upper_bound.py` ·
Artefakte `artifacts/audit_intraday_sizing_sweep_20260818.json`,
`artifacts/audit_upper_bound_20260818.json`

---

# Executive Summary (ersetzt rev5)

rev5 sagte: *„die Trennung von der Zielvorgabe ist nicht erfolgt."* **Das gilt nicht mehr.** Zwei
Messungen dieser Runde beenden die Frage:

> **Dieses Buch erreicht die 80-%-Vorgabe bei zulässigem Sizing nicht, und keine Messung, die noch
> aussteht, kann daran etwas ändern.**

Die Begründung ist konstruktiv, nicht statistisch: die Intraday-Messung liegt **per Konstruktion**
bei oder unter der Schlusskurskurve. Deren Maximum über das gesamte Raster ist **81 %**, davon
gehen −8 Punkte Verdikt-Instabilität ab, und das Kriterium verlangt keine Punktschätzung, sondern
eine **Untergrenze ≥ 0,80** — die bei n = 36 Fenstern bei **0,65** liegt.

| | rev5 | rev6 |
|---|---|---|
| Verteidigbares Sizing | 0,60× | **0,50×** — der überlappungsbeschränkte Boden ist **strenger**, nicht milder (R6-1) |
| Quote dort | 60 % | **56 %** |
| Schlussaussage | „nicht getrennt" | **getrennt: die Vorgabe wird verfehlt** |
| Selektion | offen | offen, aber begrenzt: verdeckter Abwärts-Bias **höchstens 21 pp** |
| Population | Richtung unbekannt | **Richtung gemessen: nach oben**, Größe klein (+2 bis +5 pp) |

---

# R6-1 · OQ-5 — die Messung, für die ich eine Ausnahme empfohlen habe, ging gegen mich aus

**Ich habe OQ-5 mit der Erwartung empfohlen, dass sie die Untergrenze anhebt.** Sie senkt sie. Das
gehört an den Anfang, nicht in eine Fußnote.

**[MESSUNG]** Der überlappungsbeschränkte Boden nutzt die minutengenauen Ein- und Ausstiegszeiten
und bildet je Tag das tiefste **gleichzeitige** Minimum über einen Sweep der Intervallgrenzen:

| | Schlusskurs | naiver Boden | **überlappungsbeschränkt** |
|---|---:|---:|---:|
| schlechtester Tag | −6,95 % | −9,32 % | **−11,06 %** |
| Tage ≤ −5 % | 20 | 237 | **501** |
| Übereinstimmungsgrenze | — | 0,60× | **0,50×** |

**Warum es strenger wurde, obwohl die Überlappungsbedingung Trades *ausschließt*:** weil dieselbe
Rechnung gleichzeitig den **zweiten** rev4-Vorbehalt behebt. Der naive Boden belastete die MAE eines
mehrtägigen Trades nur am **Schlusstag** und ließ die übrigen Tage, an denen die Position offen und
im Minus stand, unbelastet. Der neue Boden belastet jeden offenen Tag. Dieser Effekt überwiegt den
Ausschluss nicht-überlappender Trades deutlich.

**Was jetzt gilt:** der überlappungsbeschränkte Boden ist eine **echte tagesweise Untergrenze** —
der naive war keine, er unterschlug Tage. Die Untergrenze bei 1,00× fällt von 28 % auf **10 %**.

**Die Empfehlung ändert sich entsprechend: 0,50×, nicht 0,60×.** Dort 56 % Schlusskursquote und
56 % Bodenquote.

---

# R6-2 · Die Obergrenze — und warum sie die Frage schließt

Vollständige Kette in `UPPER_BOUND_CALC.md`. Kurzfassung:

| | |
|---|---|
| Bestmögliche Schlusskursquote im gesamten Raster | **81 %** (0,85×, 36 vollständige Fenster) · Wilson **[0,65–0,90]** |
| ./. Verdikt-Instabilität bei 0,85× | **−8 pp** (rev4 maß −6 bei 1,00×; der Effekt ist **nicht** sizing-invariant — OQ-6 damit beantwortet) |
| + Population, realistisch 21 → ~23 Sleeves | **+2 bis +5 pp** |
| ± Selektion | Punkt +3 pp, Newcombe **[−21, +32]** — nicht verwertbar |
| **Obergrenze** | **75–78 %** Punktschätzung, Untergrenze ~0,65 |

**Zwei Gründe, von denen jeder allein genügt:**

1. **Die Messung kann nichts hinzufügen.** Sie liegt bei oder unter 81 %.
2. **Das Kriterium ist eine Untergrenze.** Bei 36 Fenstern ist ein Band von 25 Punkten unvermeidbar
   — **selbst eine perfekte Messung könnte die Bar auf dieser Fensterzahl nicht erfüllen.** Das ist
   ein Stichproben-, kein Messproblem.

---

# R6-3 · Reihenfolge der Scheiter-Gründe — letzte Fassung

| neu | rev5 | Grund | Änderung |
|---|---|---|---|
| **1** | 2 | **Angebot** — 24 Paare unter 250 Handelstagen, 33 an den Gates gescheitert; 57 von 91 | **neu an der Spitze**, und erstmals beziffert |
| **2** | 1 | **Intraday** | bleibt groß (bei 1,00× 78 % gegen 10 %), entscheidet die **Vorgabe** aber nicht mehr — die ist schon oberhalb verfehlt |
| **3** | 3 | **Verdikt-Stabilität** | −3 bis −11 pp, sizing-abhängig |
| **4** | 4 | **Selektion** | nur noch als Schranke: höchstens −21 pp |

**Population ist als Scheiter-Grund gestrichen** — sie ist gemessen und zeigt nach oben. Sie ist zu
klein, um zu retten, aber sie schadet nicht.

**Die Umsortierung ist die eigentliche Nachricht der Runde:** der bindende Engpass ist nicht die
Messung und nicht das Sizing, sondern **die Zahl brauchbarer Strategien**. Das bestätigt unabhängig
die Speed-Doktrin vom 26.07.: *„Nur durch bessere Strategien."*

---

# R6-4 · Was das ausdrücklich **nicht** heißt

* **Die Strategien sind nicht widerlegt.** 21 Sleeves haben ihre Gates bestanden und tragen ein Buch,
  das in 56 bis 81 % der historischen Fenster +10 % erreicht, je nach Sizing und Messverfahren. Das
  ist kein Nullbefund.
* **Ein FTMO-Buch ist nicht als unmöglich erwiesen.** Gemessen wurde *dieses* Buch aus *diesen*
  21 Sleeves gegen *diese* Vorgabe.
* **Die Intraday-Frage bleibt betrieblich wichtig.** Ob bei 0,85× die wahre Quote 81 % oder 18 %
  ist, entscheidet über brauchbar gegen ruinös. Nur über die **Bar** entscheidet sie nicht mehr.
* **Kein Verdikt wird zurückgezogen.** Die Gates haben ihre Evidenzdateien direkt gelesen (rev3);
  die `ea_metrics`-Lücke war ein Auswertbarkeits-, kein Integritätsproblem.

---

# R6-5 · Die Anschlussfrage: war die 80-%-Vorgabe je die richtige Zielgröße?

Sie ist **selbstgesetzt** (`FTMO_BOOK_SPEC_2026-08-02_OWNER_TIMEBOX.md`), nicht von FTMO verlangt.
FTMO verlangt +10 % in Phase 1 ohne Limitbruch — nichts über die Wahrscheinlichkeit.

## Die Rechnung, die bisher niemand gemacht hat

**[MESSUNG]** Ausgangsmix je Fenster, Schlusskursbasis:

| Sizing | Stichprobe | bestanden | **Limit gerissen** | Zeit abgelaufen | E[Versuche] | **E[Tage bis zum ersten Bestehen]** |
|---:|---|---:|---:|---:|---:|---:|
| 0,60× | 50 Fenster | 60 % | **6 %** | 34 % | 1,67 | **67** |
| 0,60× | 36 vollständige | 64 % | 8 % | 28 % | 1,57 | 57 |
| 0,85× | 50 Fenster | 78 % | **12 %** | 10 % | 1,28 | **34** |
| 1,00× | 50 Fenster | 78 % | **16 %** | 6 % | 1,28 | 26 |

### Drei Befunde, die die Vorgabe in Frage stellen

**1. Der Unterschied zwischen 60 % und 80 % ist ein Drittel Versuch und rund einen Monat.**
E[Versuche] steigt von 1,28 auf 1,67; die erwartete Kalenderzeit bis zum ersten finanzierten Konto
von ~34 auf ~67 Tage. **Beides liegt innerhalb eines Quartals.** Eine Vorgabe, die ein Buch
verwirft, weil es einen Monat länger braucht, preist einen einmaligen Versuch — obwohl der Vorgang
wiederholbar ist.

**2. Die Art des Scheiterns dreht sich, und die Quote verbirgt das.** Bei 0,60× scheitern Versuche
**überwiegend an der Zeit** (34 % Ablauf gegen 6 % Limitbruch). Bei 1,00× überwiegend am
**Limitbruch** (16 % gegen 6 %). Für einen wiederholbaren Vorgang sind das keine gleichwertigen
Ausgänge: ein Ablauf kostet Gebühr und Zeit, ein Bruch kostet dasselbe **plus** die Erfahrung, dass
das Buch das Limit reißen kann — und genau dessen Wahrscheinlichkeit ist die ungemessene Größe.
**Niedrigeres Sizing tauscht Bruchrisiko gegen Zeitrisiko**, und Zeit ist billig, wenn man
wiederholen darf.

**3. Die Unabhängigkeitsannahme ist optimistisch, und sie geht gegen mich.** E[Versuche] = 1/p
unterstellt unabhängige Versuche. Sie sind es nicht: dasselbe Buch, benachbarte Regime. Ein
gescheiterter Versuch ist ein Hinweis auf ein ungünstiges Regime, das anhalten kann. **Die
tatsächliche Zeit bis zum ersten Bestehen liegt über 67 Tagen** — um wie viel, ist auf 50 Fenstern
nicht bestimmbar.

## Die Frage an OWNER

> **Ist die richtige Vorgabe „80 % je Versuch" — oder „finanziertes Konto innerhalb von X Tagen bei
> höchstens Y Brüchen"?**

Die zweite Fassung ist das, was ökonomisch zählt, und dieses Buch beantwortet sie anders als die
erste: bei **0,50×–0,60×** erreicht es das erste finanzierte Konto in erwartet **zwei Monaten** bei
einer Bruchrate von **6–8 %**.

**Das ist keine Aufweichung des Kriteriums.** Die 80 % waren nie extern vorgegeben, und die
vorliegende Rechnung ist der erste Versuch, sie zu begründen statt sie anzuwenden. Fällt die
Entscheidung für die zweite Fassung, ändert sich nicht die Messung — nur, was sie bedeutet. Fällt
sie für die erste, steht das Ergebnis aus R6-2 und die Antwort lautet: nicht mit diesem Buch.

**Was ich ausdrücklich nicht tue: die Bar eigenmächtig ersetzen.** Gate-Schwellen und
Kontraktkriterien bleiben nicht-autonom (§3.3). Dies ist eine Vorlage.

---

# R6-6 · Endstand der vier Unsicherheiten

| Unsicherheit | Stand | ohne neue Daten schließbar? |
|---|---|---|
| **Intraday** | Schranken jetzt **echt**: bei 1,00× zwischen 10 % und 78 %; Übereinstimmung bis **0,50×** | nein — verlangt Equity-Snapshots. **Ändert die Bar-Frage nicht mehr** (R6-2) |
| **Population** | gemessen, **positiv**, +2 bis +5 pp | teilweise: 11 Paare brauchen einen Lauf, 9 davon scheitern danach am 250-Tage-Filter |
| **Flip** | −3 bis −11 pp, sizing-abhängig | geschlossen (OQ-6) |
| **Selektion** | Punkt +3 pp, Schranke −21 pp | nein — verlangt ein echtes Holdout (E-3, an D-4 gekoppelt) |
