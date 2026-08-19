# RECYCLE_BACKLOG — was auf den 451 Tickets wirklich liegt

**Stand:** 2026-08-19 · Work Order Runde 10 §3
**Quelle:** `agent_tasks` (read-only), `agent_router.py:53–108`, `health.py:3153–3168`,
Abgleich gegen `framework/EAs/*/*.ex5` und `work_items`

---

## 0 · Die Antwort, und sie ist ernüchternd

> **Die 451 sind keine vier Wochen Zufluss. Sie sind drei EAs.**
>
> 290 Tickets sind Bauaufträge, die nie einen EA erzeugt haben. 117 zeigen auf EAs, die längst
> gebaut **und** längst durch die Fabrik gelaufen sind. **Genau 3 EAs sind gebaut und nie
> eingereiht** — das ist der gesamte verborgene Vorrat.

---

## 1 · Was `RECYCLE` bedeutet — §3.1, aus dem Code

`agent_router.py:59`: `REVIEW_CLOSE_STATES = {"APPROVED", "BLOCKED", "FAILED", "RECYCLE"}`

**`RECYCLE` ist ein Review-Abschluss, kein Zwischenzustand des Bauprozesses.** Es heißt: *zurück
zur Überarbeitung*. Dazu `RECYCLE_MAX_ATTEMPTS = 3` (`:106`).

Der entscheidende Satz steht in `health.py:3153`:

> *„The deterministic router selects only BACKLOG/TODO; RECYCLE, APPROVED and PIPELINE are a
> router-exitless limbo state."*

> **Der Router holt RECYCLE nie wieder ab.** `LIMBO_STATES = ("RECYCLE", "APPROVED", "PIPELINE")`.
> Ein Ticket, das dort landet, wird von nichts mehr angefasst — es ist dieselbe Klasse wie die
> Mechanismen ohne Aufrufer, nur auf der Ticketebene.

## 2 · Was dort liegt — §3.2, gemessen

**[MESSUNG]** 451 Tickets, 410 mit einer auflösbaren `QM5_`-Kennung:

| | Anzahl |
|---|---:|
| Tickets insgesamt | **451** |
| davon mit EA-Kennung | 410 |
| **EAs mit kompilierter `.ex5`** | **120** |
| **EAs bereits in `work_items`** (schon gelaufen) | **117** |
| **gebaut, aber nie eingereiht** | **3** |
| **weder gebaut noch eingereiht** | **290** |

Die drei: `QM5_1157`, `QM5_1619`, `QM5_41002`.

**Damit zerfällt der Bestand in zwei Gruppen, und keine ist der erhoffte Nachschub:**

* **290 unerledigte Bauaufträge.** Sie haben nie einen EA erzeugt. Sie durchzureichen heißt, 290
  Builds zu fahren — das ist kein vorhandenes Angebot, sondern Arbeit im selben Umfang wie eine
  Neuentwicklung aus der Karte.
* **117 bereits gelaufene EAs.** Sie sind Überarbeitungs-Tickets auf Kandidaten, die die Fabrik
  längst kennt. Ihr Wert liegt in der Reparatur, nicht im Zulauf.

## 3 · Was sie gestoppt hat — §3.3

**[MESSUNG] Verdikte:**

| Verdikt | Tickets |
|---|---:|
| „batch adjudication 2026-07-19 (Claude, wf_11f17900 verified)" | **296** |
| „auto-recycle: Gemini v2 rework wave (OWNER 2026-06-03)" | 77 |
| „CLAUDE REVIEW RECYCLE — not built. Battery findings: no_ex5…" | 35 |
| „auto-recycle: news-calendar bypass qm_news_stale_max_hours=8…" | 13 |
| „RECYCLE: build_ea PASS verdict is false — build is incomplete" | 10 |
| „auto-recycle: build artifact missing (phantom)" | 5 |

**Zeitliche Verteilung:** 2026-05: 10 · 2026-06: 99 · **2026-07: 301** · 2026-08: 41.

**Sie sind nicht über Monate gleichmäßig aufgelaufen, sondern in zwei Wellen:** eine
Gemini-v2-Überarbeitungswelle im Juni (OWNER-Beschluss vom 03.06.) und eine
**Batch-Adjudikation am 19.07., die allein 296 Tickets erzeugt hat.** Beide waren bewusste
Entscheidungen, keine Fehler — und beide endeten in einem Zustand, aus dem der Router nicht
zurückholt.

**Damit ist die Ursache benannt:** nicht ein Fehler, nicht eine Kapazitätsgrenze, sondern eine
**Zustandssenke.** Zwei Massenaktionen haben Tickets korrekt nach RECYCLE geschlossen, und danach
hat sie niemand wieder aufgenommen, weil dafür kein Mechanismus existiert.

## 4 · Was es kostet — §3.4

**Gegen die 185 gebauten EAs je zusätzlichem Sleeve gerechnet:**

| Gruppe | Zahl | Aufwand je Stück | Erwartung |
|---|---:|---|---|
| gebaut, nie eingereiht | **3** | ~null (einreihen) | **der einzige billige Posten** |
| bereits gelaufen | 117 | Überarbeitung + erneuter Durchlauf | Reparaturwert, kein Zufluss |
| nie gebaut | 290 | ein voller Build je Ticket | identisch zur Neuentwicklung |

> **Der billige Teil sind drei EAs.** Bei einer Ausbeute von 0,54 % je gebautem EA ist der
> Erwartungswert von drei EAs rund **0,016 Buch-EAs** — praktisch null.
>
> Die 290 Bauaufträge sind **kein günstigerer Nachschub als der reguläre Weg**, sondern derselbe
> Weg mit einem älteren Datum. Ihr einziger Vorteil: die Karte existiert bereits.

**Antwort auf §3 in einem Satz:** die 451 sind kein verborgenes Angebot, sondern eine Senke, in der
zwei Massenaktionen liegen geblieben sind — und ihr verwertbarer Anteil ist dreistellig klein,
nämlich drei.

## 5 · Schnittmenge mit §1 — §3.5

**[MESSUNG]** Universen der recycelten EAs, soweit Karten auffindbar: FX 58 %, Index 22 %,
Metall 15 %, Energie 2 %. Meistgenannte Symbole: XAUUSD 6, EURUSD 5, NDX 3, WS30 3, GBPUSD 3.

**Sie nennen dieselben Symbole wie der Bestand** — der Vorrat wäre also auch dann nicht besonders
wertvoll, wenn er größer wäre.

## 6 · Empfehlung

1. **Die drei einreihen** (`QM5_1157`, `QM5_1619`, `QM5_41002`) — nach der üblichen Prüfung Magic,
   Karte, keine neuere Variante. Kostet nichts, bringt fast nichts, schließt aber eine Lücke.
2. **Die 117 nicht anfassen.** Sie sind gelaufen; eine Überarbeitung lohnt nur bei einem konkreten
   Reparaturbefund.
3. **Die 290 als das behandeln, was sie sind:** Kandidaten für die reguläre Bau-Warteschlange, mit
   derselben Priorität wie eine neue Karte — und nach den Symbolregeln aus `SYMBOL_RANKING_PAIRED.md`
   sortiert, nicht nach Alter.
4. **Die Senke schließen.** `LIMBO_STATES` ohne Rückholmechanismus ist ein struktureller Defekt:
   jede künftige Massenadjudikation erzeugt denselben Stau. → **OQ-23**

**Nichts durchgereicht.** Dieses Dokument ist die Aufklärung, die §3 vor jeder Handlung verlangt.
