# Strategy Archive Matrix — Spezifikation v1.0 (alle acht Entscheidungen getroffen)

**Autor:** Claude (Design/IA-Lane, Orchestrator) · **Datum:** 2026-08-23
**Status:** ENTSCHIEDEN — alle acht Fragen vom OWNER beantwortet (2026-08-23). Baureif, sobald der
Prototyp gemessen ist. Die Gate-Umnummerierung (§3a) ist ein **eigener Auftrag** und blockiert die
Matrix nicht.
**Programm:** Vault `12 ToDo/03_Mission_Control_Cockpit` · **Nachbarspec:** `docs/ops/MISSION_CONTROL_V2_RENDER_SPEC.md`
**Zielfläche:** `D:\QM\strategy_farm\dashboards\strategies.html` (heißt bereits „Strategy Archive") — **erweitern, nicht neu bauen.**

## 0 · Auftrag (OWNER 2026-08-23)

Die gesamte Datenbank sichtbar machen: erste Spalte Strategy-Card-Nr., danach die Gates als
Spalten, in den Feldern welche Karte auf welchem Symbol schon getestet wurde. Grün = Backtest
PASS, rot = FAIL, grau = Backtest steht noch aus, leer = kein Backtest geplant und nicht mehr
sinnvoll. Spaltenkopf-Gruppen: ab Q00 blau (Evaluierung), orange (Optimierung), violett
(Portfolio-Build). Spalten sortierbar. Zweck: **Löcher selbst identifizieren.**

Antwort in einem Satz: **Ja, das ergibt Sinn — und es ist die Seite, die dem Betrieb heute
fehlt.** Zwei Stellen tragen die Idee aber nicht so, wie sie formuliert ist, und beide sind
gemessen, nicht vermutet: (1) 90 % der Fläche ist leer und der größte Teil dieser Leere ist
*korrekt*, (2) das Vier-Farben-Schema hat keinen Platz für den häufigsten Nicht-Zustand der
Datenbank — den verbrannten Lauf ohne wirtschaftliches Urteil.

## 1 · Messbefund (alle Zahlen 2026-08-23, `farm_state.sqlite` über `work_items_clean`)

| Größe | Wert | Quelle |
|---|---|---|
| Approved Strategy Cards | 3.279 | `D:\QM\strategy_farm\artifacts\cards_approved\*.md` |
| EA-IDs mit mindestens einer Gate-Zeile | 3.093 | `SELECT COUNT(DISTINCT ea_id) FROM work_items` |
| (EA, Symbol)-Paare | 14.642 | dito |
| Work-Item-Zeilen gesamt | 111.620 | dito |
| **Belegte Zellen (EA, Symbol, Gate)** | **25.235** | jüngste Zeile je Tripel |
| Symbolwerte in der DB | 290 (inkl. 129 Zeilen mit leerem Symbol = Basket) | dito |

**Dichte.** Zeilenmodell „ein Paar pro Zeile" × 17 Gate-Spalten = 248.914 Felder, davon 25.235
belegt = **10,1 %**. Die Matrix ist konstruktionsbedingt zu 90 % leer, und das ist meistens
richtig so: Q05 ist leer, *weil* Q04 nie bestanden wurde. Eine naive Matrix ist deshalb eine
graue Wand, in der das Auge nichts findet. Der Informationsträger ist nicht „leer", sondern
**„erreichbar und trotzdem leer"**.

**Kettenwanderung (Paare, die die Kette lückenlos bis zum Gate gehen und dort PASS haben):**

```
Q02 6.395 → Q03 1.574 → Q04 270 → Q05 179 → Q06 158 → Q07 107 → Q08 15 → Q09 0 → Q10 0
```

**Erreichbare Löcher (Vorgänger-Gate PASS, Nachfolger-Gate hat keine einzige Zeile):**

```
Q03: 4.661   ·   Q02: 4   ·   Q07: 1   ·   alle übrigen Gates: 0
```

**4.661 Paare haben Q02 bestanden und besitzen keine Q03-Zeile.** Das ist der Arbeitsvorrat des
Leerlauf-Programms in einer Zahl — und genau das Loch, das die Seite sichtbar machen soll.
(Vorbehalt: ein Teil davon dürfte auf zurückgezogenen Identitäten oder retirierten Symbolen
sitzen; siehe F4/F5. Die Zahl ist eine Obergrenze, kein Auftragsbestand.)

## 2 · Zeilenmodell — **F1**

| | A — Zeile = Card *(empfohlen)* | B — Zeile = (Card, Symbol) | C — beide, umschaltbar |
|---|---|---|---|
| Zeilen | 3.279 | 14.642 | beides |
| Zelle | Symbolstreifen (ein Chip je Symbol) | ein einziges Feld | — |
| Beantwortet | „welche Karte hat Löcher" | „welches Paar hängt" | beides |
| Sortierung | nur über abgeleitete Skalare (§7) | direkt | — |
| Seitengröße | mittel | groß | groß |

Empfehlung **A mit Aufklappen**: Kartenzeile zeigt pro Gate einen kompakten Symbolstreifen,
Klick auf die Zeile klappt die Paar-Zeilen darunter auf (Modell B on demand). Damit ist die
Fläche in einem Blick lesbar und die Detailfrage einen Klick entfernt.

```
Card            │ Q00 Q01 │ Q02     Q03       Q04   Q05 … │ Q14 Q15 Q16 │ Q11 Q12 Q13
QM5_11516       │  ●   ●  │ ●●●○▨   ●●·       ●·          │  ·   ·   ·  │  ·   ·   ·
  ├ EURUSD.DWX  │  ●   ●  │ ●       ●         ●           │
  ├ XAUUSD.DWX  │  ●   ●  │ ●       ⊙ Loch                │
  └ NDX.DWX     │  ●   ●  │ ▨ VOID  ·                     │
```

## 3 · Spalten und Farbgruppen — **F2**

Kanonische Gates (Gate-Manifest, `tools/strategy_farm/phase_ids.py`):

- **Blau — Evaluierung:** Q00 Research Intake · Q01 Build & Spec · Q02 Baseline Screening ·
  Q03 Parameter Sweep · Q04 Walk-Forward + Commission · Q05 Gross Full-History Robustness ·
  Q06 Stress HARSH · Q07 Multi-Seed · Q08 Davey Statistical Validation ·
  Q09 News Impact + FTMO Recommendation · Q10 Incumbent Full-History Confirmation
- **Orange — Optimierung:** Q14 Pattern Filter Selection · Q15 Parameter Optimization & Freeze ·
  Q16 Best-Settings Head-to-Head
- **Violett — Portfolio/Betrieb:** Q11 Final Portfolio Construction · Q12 Operational Readiness ·
  Q13 Live Burn-In DXZ

**Die Reihenfolge ist die Frage.** Die Farbfolge blau → orange → violett entspricht dem
*Fluss* (`Q10 → Q14 → Q15 → Q16 → Q11`), nicht der *Zahlenfolge* (`Q11 … Q13`, dann `Q14 … Q16`).
Beide sind vertretbar; die Flussreihenfolge liest sich als Pipeline, die Zahlenreihenfolge als
Register. Ich brauche die Entscheidung, weil sie im Kopf der Seite dauerhaft steht.

Nebenpunkte derselben Frage:
- **Q09 zerfällt in der DB in `Q09_NEWS` und `Q09_PORTFOLIO`** (122 Zellen zusammen). Eine
  Spalte mit zwei Halbfeldern, oder zwei Spalten?
- **Q00/Q01 stehen nicht in `work_items`.** Q00 wäre aus dem Card-Bucket abzuleiten
  (`cards_approved` vs `cards_rejected/_draft/_review`), Q01 aus `.ex5`-Existenz + APPROVED-Review
  in `agent_tasks`. Machbar, aber eine zweite Quelle. → **F8**
- Nicht-Gate-Phasen der DB (`COMPILE_EA` 129, `P2` 33, `OPT_CENSUS`, `HARNESS_PP_FIXTURE`)
  bekommen keine Spalte; `P2` ist ein Legacy-Alias von Q02 und wird dorthin gefaltet.

## 4 · Zellzustände — **F3 (der wichtigste Punkt)**

Gemessene Taxonomie der 25.235 jüngsten Zellen:

| Taxonomie | Zellen | bedeutet |
|---|---:|---|
| `strategy` | 20.630 | echtes wirtschaftliches Urteil (PASS/FAIL/ZERO_TRADES/…) |
| `open` | 2.216 | pending/active/claimed — läuft oder wartet |
| `infra` | 1.517 | Lauf verbrannt (Timeout, Cold Cache, EX5 fehlt …) |
| `invalid` | 548 | Lauf ungültig (Evidenz unvollständig) |
| `governance` | 114 | superseded / obsolete / blocked |
| `unknown` | 100 | nicht klassifizierbar |
| `review` | 73 | REVIEW_REQUIRED / NEED_MORE_DATA |
| `draft_defect` | 36 | Card-Defekt vor dem Lauf |
| `measurement` | 1 | OPT_CENSUS-Messung (nie PASS/FAIL) |

**2.165 Zellen (8,6 %) tragen kein wirtschaftliches Urteil.** Im Vier-Farben-Schema müssten sie
entweder rot werden (falsch — die Strategie ist nicht gescheitert, die Infrastruktur ist es) oder
grau (falsch — es sieht aus wie „steht noch aus", tatsächlich liegt ein verbrannter Lauf vor, der
requeued werden muss). Beides würde beim Löchersuchen in die Irre führen. Die Hausregel dazu
steht bereits: *Infra ist nie Merit.*

Vorschlag **sieben Zustände**, Farbe nie alleiniger Träger (Glyphe dazu, farbfehlsichtigkeitsfest):

| # | Zustand | Darstellung | gemessen |
|---|---|---|---|
| 1 | **PASS** | grün ● | 9.267 (+ PASS_PORTFOLIO 8) |
| 2 | **PASS bedingt** | grün hohl ◐ (PASS_SOFT, PASS_LOWFREQ) | 330 |
| 3 | **FAIL wirtschaftlich** | rot ● (FAIL, ZERO_TRADES, FAIL_HARD/SOFT, RETIRE, …) | 10.949 |
| 4 | **VOID / verbrannt** | amber schraffiert ▨ (infra + invalid) | 2.165 |
| 5 | **läuft / in Queue** | grau ○ | 2.216 |
| 6 | **erreichbares Loch** | grau umrandet mit Punkt ⊙ — Vorgänger PASS, keine Zeile | 4.666 |
| 7 | **nicht anwendbar** | kein Chip, Feld bleibt leer | Rest |

`governance` (114) und `review` (73) laufen als dünner Rahmen auf dem jeweiligen Chip mit, Grund
im Tooltip — sie sind Randnotizen, keine eigene Farbe.

Zustand 6 ist der eigentliche Zweck der Seite. Frage: **soll er optisch aggressiv sein**
(kräftiger als PASS/FAIL, weil er der Arbeitsvorrat ist) oder ruhig?

## 5 · Welcher Lauf entscheidet die Zelle? — **F4**

Regel-Vorschlag: **jüngste Zeile je (Card, Symbol, Gate)** aus `work_items_clean`,
Zukunftszeitstempel ausgeschlossen (bestehende Praxis in `collect_archive_v2`).

Das kollidiert mit einer Regel von heute früh: **„rebuilt EX5 = neue Identität ab Q02".** Ein
PASS vom Juni auf einem seither neu gebauten EA ist kein gültiger PASS mehr — die Zelle wäre
grün und die Aussage falsch. Drei Wege:

- (a) jüngstes Verdikt zeigen, Identität ignorieren — einfach, aber die Seite lügt bei Rebuilds
- (b) **Verdikte älter als der aktuelle Build-Hash als „stale pass" hohl darstellen** *(empfohlen)*
- (c) sie wie ein Loch behandeln — ehrlich, aber vernichtet sichtbare Historie

(b) kostet eine Build-Hash-Verknüpfung pro Zelle. Vor der Umsetzung ist zu messen, für wie viele
Zeilen der Hash überhaupt vorliegt; ist die Abdeckung schlecht, wird (b) zu (a) mit sichtbarem
Warnhinweis. Das ist eine Messung, keine Vertragsänderung.

## 6 · „Leer, weil nicht mehr sinnvoll" — **F5**

Das System weiß das heute nicht. Es gibt kein Feld „nicht geplant". Ableitbar sind vier Signale:

1. Symbol gehört nicht zum Zieluniversum der Card (`target_symbols`)
2. Paar/EA ist `RETIRE` / `RETIRED_LOW_FREQ` / `OBSOLETE_NON_DWX_SYMBOL` / `SUPERSEDED` (governance)
3. Card liegt in `cards_rejected` / `cards_blocked_r3_data`
4. es liegt ein `work_item_holds`-Eintrag vor

Frage: reicht diese Ableitung als Definition von „leer"? Oder soll es ein **pflegbares Feld
„nicht geplant (Grund)"** geben — dann braucht es eine Quelle und einen Setzer dafür, und das ist
ein neuer Datenvertrag, kein Rendering.

## 7 · Sortierung — **F6**

Bei Zeilenmodell A enthält eine Gate-Spalte mehrere Symbole; sortierbar wird sie nur über einen
Skalar. Vorschlag: jede Zelle trägt verdeckt `(n_pass, n_fail, n_void, n_hole)`. Sortierschlüssel
pro Gate-Spalte umschaltbar: PASS-Anzahl · Loch-Anzahl · Fortschritt.

Zeilen-Sortierschlüssel: höchstes bestandenes Gate · Anzahl erreichbarer Löcher · letzte Aktivität ·
Card-Nr. · Archetyp.

Frage: **Default-Sortierung** = „meiste erreichbare Löcher zuerst" (Arbeitsvorrat) oder
„höchstes bestandenes Gate zuerst" (Bestenliste)?

## 8 · Filter (empfohlen, keine offene Frage)

Symbolfilter (reduziert alle Zellen auf ein Symbol → die Matrix wird zur reinen Card×Gate-Tafel) ·
„nur Löcher" · „nur VOID" · Card-Suche · Archetyp/Quelle · Card-Bucket. Das Filter- und Sortier-JS
existiert bereits (`ARCHIVE_V2_JS` in `tools/strategy_farm/dashboards/render_dashboards.py`).

## 9 · Symboluniversum — **F7**

290 Symbolwerte, davon ein Schwanz obsoleter Nicht-DWX-Symbole (196 Zeilen `OBSOLETE_NON_DWX_SYMBOL`)
und 129 Zeilen mit **leerem** Symbol (Basket-EAs mit logischem Symbol). Vorschlag: Chips nur für die
handelbaren DWX-Symbole aus `dwx_symbol_matrix.csv` (die Top-19 tragen die Masse: EURUSD 1.774 EAs,
GBPUSD 1.576, XAUUSD 1.350, USDJPY 1.158, NDX 1.016, GDAXI 804, WS30 753, XTIUSD 605, SP500 572,
AUDUSD 564 …), Rest gebündelt als `legacy`, Basket-Zeilen als eigener Chip `BASKET` — sonst
verschwinden sie lautlos.

## 10 · Ort, Technik, Kosten

- **Erweitern statt neu:** `strategies.html` heißt bereits „Strategy Archive"; die Matrix wird dort
  die Leitsektion, der bestehende EA-Index bleibt darunter.
- **Datenweg steht zu 80 %:** `collect_archive_v2()` liefert heute `cell_latest[(ea, symbol)]` in
  einem einzigen Durchlauf über `work_items_clean`. Die Matrix braucht denselben Durchlauf mit
  Gate als drittem Schlüssel — ein Feld mehr in derselben Schleife, kein neuer Query-Pfad.
- **Nicht ins Cockpit:** die MC-v2-Spec schließt Drill-down aus dem Cockpit ausdrücklich aus. Das
  Cockpit verlinkt, gerendert wird im bestehenden Dashboard-Task.
- **Seitengröße:** heute 1,4 MB. Modell A grob geschätzt 3–6 MB, Modell B deutlich mehr. Das ist am
  Prototyp zu messen, bevor abgenommen wird; Ausweg wäre kompakte `data-`Kodierung mit
  clientseitigem Zellaufbau.
- **Read-only absolut:** keine Requeue-Buttons, keine Aktionspfade (MC-v2-Prinzip). Kennzahlen
  (Trades, PF, DD) gehören nicht in die Matrix, sondern bleiben auf der EA-Detailseite.

## 11 · Akzeptanzkriterien (Entwurf)

1. Jede Card mit ≥1 Gate-Zeile erscheint; Zeilenzahl == DB-Zahl (Test).
2. Summe aller Zellzustände == Anzahl der (Card, Symbol, Gate)-Gruppen — keine Doppelzählung.
3. Kein `P[0-9]`-Gate-Token im gerenderten HTML (Qxx-Regel, wie MC-v2).
4. Jede Zelle verlinkt auf die EA-Detailseite; jeder Chip nennt im Tooltip Verdikt, Datum, Work-Item-ID.
5. Sortieren und Filtern ohne Serverlauf, gemessen < 500 ms auf der vollen Zeilenzahl.
6. Legende erklärt alle sieben Zustände, VOID und Loch ausdrücklich benannt.
7. Farbe ist nie alleiniger Informationsträger (Glyphe je Zustand).
8. Die Seite trägt sichtbar den Zählstand und den Renderzeitpunkt.

## 3a · OWNER-Rückfrage zu F2: „die Gates müssen richtig nummeriert werden" (2026-08-23)

Der OWNER hat F2 nicht als Layoutfrage beantwortet, sondern als Defekt benannt: Nummer und
Reihenfolge sollen übereinstimmen, überall, damit daraus keine Fehler mehr entstehen.

**Die Ursache ist keine schlampige Nummerierung, sondern eine Verzweigung.** Q14–Q16 sind kein
Abschnitt, sondern ein Abzweig: `Q10 → Q11` (gewöhnlich) oder `Q10 → Q14 → Q15 → Q16 → Q11`
(Optimierung). In einer Verzweigung springt bei *jeder* linearen Nummerierung einer der beiden
Wege. Nummeriert man den Optimierungszweig aufsteigend (Q11=Pattern, Q12=ParamOpt, Q13=H2H,
Q14=Portfolio, Q15=Ops, Q16=Burn-In), springt stattdessen der **gewöhnliche** Weg (Q10 → Q14) —
und den geht praktisch jeder EA. Gemessen: `work_items` enthält **15 Zeilen** im Optimierungszweig
(Q14: 14, Q15: 1, Q16: 0) gegen 111.605 Zeilen im gewöhnlichen Weg. Der geradlinige Umbau würde
also einen seltenen Sprung gegen einen häufigen tauschen.

**Der Mechanismus für die saubere Lösung existiert bereits.** Das aktive Gate-Manifest
(`tools/strategy_farm/config/gate_manifest.v3.json`, seit 2026-08-23 aktiv, fail-closed
Aktivierungsguard) kennt bereits eine Unterstufe mit `top_level: false` — **Q10A „Baseline Full
Run"**. Damit lässt sich der Abzweig als Abzweig ausdrücken, statt ihn in die Hauptkette zu
pressen:

| Variante | Hauptkette | Optimierungszweig | historische Dokumente | Aufwand |
|---|---|---|---|---|
| **(1) Unterstufen `Q10.1–Q10.3`** *(Empfehlung)* | Q00…Q13 lückenlos aufsteigend, kein Sprung | liest sichtbar als Abzweig von Q10, kehrt nach Q11 zurück | Q11–Q13 bewegen sich **nicht** → keine Doppelbedeutung | klein: Manifest v4 + 15 DB-Zeilen + ~30 Task-Payloads + Doku zu Q14–Q16 |
| (2) Vollumnummerierung | Q10 → Q14 springt (häufiger Weg) | aufsteigend | **jedes** dokumentierte Q11–Q16 bekommt eine zweite Bedeutung | groß, siehe unten |
| (3) nur Anzeigereihenfolge | unverändert | unverändert | unverändert | minimal, löst das Problem aber nicht |

**Gemessener Radius einer Vollumnummerierung (Variante 2):** 9.491 Token-Vorkommen `Q11`–`Q16` in
3.709 Dateien — 2.490 Markdown, 1.121 EA-Quellen (`.mq5`, Kommentarzeilen mit Q13-Bezug), 58 Python,
29 JSON, 7 `.set`. Laufzeitseitig ist es dagegen fast frei: **15 Work-Item-Zeilen** und rund 30
`agent_tasks`-Payloads. **Der teure Teil ist die Evidenzspur, nicht der Code.** `decisions/` ist
nach Datum unveränderlich (Repo-Regel) — eine Vollumnummerierung erzeugt dort dauerhaft zwei
Bedeutungen desselben Tokens und braucht zwingend eine veröffentlichte Alias-Tabelle plus die
Regel, dass datierte Dokumente ihre alten Nummern behalten. Variante (1) vermeidet genau das,
weil Q11–Q13 stehen bleiben und nur Q14–Q16 (15 DB-Zeilen) in `Q10.1–Q10.3` übergehen.

**Weg, falls OWNER umnummeriert:** (a) Entscheidungsrecord `decisions/DL-NNN` mit Zielschema und
Alias-Tabelle, (b) Gate-Manifest **v4** über den bestehenden Aktivierungsguard (READ_INERT →
Review → ACTIVE), (c) mechanische Doku-Passe mit Fixture-Test — datierte `decisions/`-Dateien
werden nicht angefasst, (d) erst danach rendert die Archivmatrix das neue Schema. Schritt (c) ist
die Stelle, an der eine breit angelegte Agentenwelle sinnvoll ist; die Schritte (a)/(b) sind
Vertragsarbeit und bleiben in der Claude-Lane.

**Bis das entschieden ist, ist F2 für die Matrix nicht blockierend:** die Spaltenreihenfolge liest
sich aus `extension_topology` des Manifests, egal welches Schema dort steht.

## 11a · OWNER-Entscheide vom 2026-08-23 — vollständig

| | Entscheidung | Folge für den Bau |
|---|---|---|
| **F1** | **A — Zeile ist die Card**, aufklappbar zu (Card, Symbol) | 3.279 Zeilen; Gate-Zelle trägt Symbolstreifen; Spaltensortierung über abgeleitete Skalare |
| **F2** | **Unterstufen `Q10.1–Q10.3`** statt Vollumnummerierung | eigener Auftrag (§3a/§14); Matrix liest die Reihenfolge ohnehin aus `extension_topology` |
| **F3** | **Sieben Zustände, Loch-Chip auffällig** | VOID (2.165) bekommt eigene Darstellung; das erreichbare Loch (4.666) ist der kräftigste Chip der Seite |
| **F4** | **Gemessen 2026-08-23: 17,1 % Abdeckung → (a)**, jüngstes Verdikt, Warnbanner statt Zellchip | `docs/ops/evidence/archive_matrix_hash_coverage_measurement_2026-08-23.md`; 422 gemessen-stale Zellen als Fußnote/Filter, nicht als Zustand 2; Zustand 2 bleibt nur für `PASS_SOFT`/`PASS_LOWFREQ` (nie hash-abhängig) |
| **F5** | **abgeleitet aus vier Signalen** (Zieluniversum · RETIRE/OBSOLETE/SUPERSEDED · Card-Bucket · `work_item_holds`) | kein neuer Datenvertrag; **jede leere Zelle nennt ihren Grund im Tooltip**, keine stillschweigende Leere |
| **F6** | **Default: höchstes bestandenes Gate zuerst** | Seite öffnet als Bestenliste; „meiste Löcher zuerst" bleibt ein Klick im Sortiermenü, der Loch-Filter bleibt prominent |
| **F7** | **DWX-Chips + `legacy` + `BASKET`** (Claude, Routineurteil) | Basket-EAs mit leerem Symbol verschwinden nicht |
| **F8** | **Matrix beginnt bei Q02** | eine einzige Quelle (`work_items_clean`), eine Frische, einfacher Test. Die blaue Kopfgruppe heißt weiter „Evaluierung", beginnt aber sichtbar bei Q02 |

**Bewusst in Kauf genommen (F8):** Karten ohne jede Gate-Zeile erscheinen nicht. Der Stau *vor*
der Fabrik — freigegebene Karten, die nie gebaut wurden — bleibt damit unsichtbar; er ist über das
Drain-Programm und `D1` abgedeckt, nicht über diese Seite. Die Seite schreibt das sichtbar in die
Fußzeile, damit die Abwesenheit nicht als Vollständigkeit gelesen wird.

## 14 · Umsetzungsreihenfolge

1. **Messung vor dem Prototyp:** Build-Hash-Abdeckung je Zelle (entscheidet F4 (b) gegen (a)).
2. **Prototyp** auf echten Daten, Card-Stichprobe über alle Gates; Seitengröße und Sortierlatenz
   gemessen (Akzeptanz §11).
3. **OWNER-Abnahme** am Prototyp.
4. **Vollausbau** in `render_dashboards.py`, Tests nach §11, Verlinkung aus dem Cockpit-Kopf.
5. **Unabhängig davon** läuft der Nummerierungsauftrag (§3a): Entscheidungsrecord → Gate-Manifest
   v4 (READ_INERT → Review → ACTIVE) → mechanische Doku-Passe. Die Matrix übernimmt das Schema
   automatisch, weil sie die Reihenfolge aus dem Manifest liest.

## 12 · Fragen F1–F8 — geschlossen 2026-08-23

Alle acht Entscheidungen stehen in §11a. Historie der Fragestellung: Git-Historie dieser Datei (v0.1/v0.2).

## 13 · Nächster Schritt

Prototyp auf echten Daten (kein Mock), eine Card-Stichprobe über alle Gates, Seitengröße und
Sortier-Latenz gemessen — dann Abnahme, dann Vollausbau im Dashboard-Task. Der Prototyp ist
Design-Arbeit der Claude-Lane; der Vollausbau kann an Codex gehen, sobald die Zellsemantik steht.
