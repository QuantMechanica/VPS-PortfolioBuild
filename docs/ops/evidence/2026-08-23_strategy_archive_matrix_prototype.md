# Strategy Archive Matrix — Prototyp + Datenbank-Befund (2026-08-23)

**Auftrag:** OWNER 2026-08-23 („bau den Prototyp") · **Spec:** `docs/ops/STRATEGY_ARCHIVE_MATRIX_SPEC_2026-08-23.md` v1.0
**Renderer:** `tools/strategy_farm/dashboards/render_archive_matrix_prototype.py`
**Ausgabe:** `D:\QM\strategy_farm\dashboards\strategy_archive_matrix_prototype.html`
**Router:** `2ee6427d` · **ToDo:** `QM-TODO-20260823-501`

## 1 · Prototyp — gemessen

| Größe | Wert |
|---|---|
| Seitengröße | **3,61 MB** (heutige `strategies.html`: 1,4 MB) |
| Kartenzeilen | 2.984 |
| Gezeichnete Chips | 30.461 |
| Belegte Zellen aus der DB | 25.077 |
| Erreichbare Löcher | 5.377 |
| Erhebung (voller DB-Scan, 111.621 Zeilen) | 1,8 s |
| Rendern | 0,2 s |
| Detailmodell (Paarzeilen, clientseitig) | 300 KB JSON, 15.190 Paare |

**Löcher je Gate:** Q03 4.658 · Q02 680 · Q11 30 · Q10 8 · Q07 1.
Die 680 in Q02 sind zu 678 **Zielsymbole aus dem Karten-Frontmatter, die nie einen Lauf hatten** —
zweite Quelle, auf der Seite getrennt ausgewiesen.

**Zellzustände:** PASS 9.274 · PASS bedingt 330 · FAIL 11.017 · VOID 2.273 · läuft/Queue 2.183.
Summe = 25.077 = Anzahl der (Card, Symbol, Gate)-Gruppen → **Akzeptanzkriterium 2 erfüllt**.

### Verifikation gegen die Datenbank

Vollabgleich Modell ↔ `work_items_clean` über alle 2.984 Karten:

```
DB-Zellen: 25.077  | im Modell fehlend: 0  | falscher Zustand: 0
Modell-Zellen gesamt: 30.454  (davon Löcher 5.377)
Löcher mit DB-Zeile (muss 0 sein): 0
Modellzellen ohne DB-Zeile und kein Loch (muss 0 sein): 0
```

### Ein Defekt, der beim Bauen auffiel und behoben wurde

Die erste Fassung ließ den Kettenlauf beim ersten FAIL abbrechen und **verschluckte damit 5.382
gemessene Zellen** — auf einer Seite, die behauptet, die ganze Datenbank zu zeigen. Jetzt getrennt:
gezeichnet wird *alles*, was in der DB steht; der Kettenlauf bestimmt **nur** das Loch.

### Zwei bewusste Abweichungen von der Spezifikation

1. **Der Stale-Pass-Chip (F4) fehlt.** Die zugesagte Messung ergab: die Datenbank führt keine
   belastbare Build-Identität je Zelle. `expected_ex5_sha256` steht in **119 von 40.000**
   Payloads (0,3 %). Der Dateizeitstempel des `.ex5` als Ersatz würde **19.595 von 26.631
   PASS-Zeilen (73,6 %)** als veraltet markieren — dominiert von Recompiles und
   Include-Spiegelung, die den EA nicht verändern. Damit greift der vorregistrierte Rückfall
   (Variante a): jüngstes Verdikt, sichtbar gewarnt.
2. **Die Zweigspalten tragen bereits `Q10.1–Q10.3`** mit dem heutigen Speichertoken als
   Kleinschrift, damit der OWNER-Entscheid sichtbar ist, bevor Gate-Manifest v4 existiert.

## 2 · Datenbank-Befund (OWNER-Frage: „ist die Datenbank fehlerhaft, funktioniert sie korrekt?")

Die Matrix muss jede Zelle anfassen und ist damit zugleich eine Datenqualitätsprüfung. Ergebnis:
**die Datenbank funktioniert als Schaltzentrale — ihre gespeicherten Urteilsfelder sind aber nicht
vertrauenswürdig, die Korrektur existiert nur zur Lesezeit.**

### Was gesund ist

- `PRAGMA quick_check` = **ok**, WAL-Journal, 404 MB, 8 Indizes auf `work_items`/`agent_tasks`
  (u. a. `idx_work_items_ea_phase`, `idx_work_items_verdict_ea`).
- Voller Scan über 111.621 Zeilen in **1,8 s** — die Engine ist für diese Last nicht der Engpass.
- Die Metrikschicht `ea_metrics` ist mit 63.329 Zeilen gefüllt und trägt die Zahlen, die
  `work_items` bewusst nicht speichert.
- Der Zustandsautomat läuft: die Fabrik arbeitet seit Monaten aus genau diesen Tabellen.

### Was defekt ist — jede Zahl aus `work_item_clean_view.py --db …`

| Befund | Zeilen | Bedeutung |
|---|---:|---|
| `invariant.valid` | **false** | die Kombination Status × Verdikt × Taxonomie ist nicht durchgängig gültig |
| `unknown_combination` | 107 | Zeilen, die sich keiner Taxonomie zuordnen lassen |
| `status_restamped` | **9.381** | der **gespeicherte** Status widerspricht dem Verdikt; die Sicht korrigiert ihn beim Lesen, die Tabelle bleibt falsch |
| `taxonomy_derived` | **50.883** | fast die halbe Datenbank hat gar keine gespeicherte Taxonomie |
| `taxonomy_restamped` | 786 | gespeicherte Taxonomie widerspricht dem Verdikt |
| `reason_suppressed` | 3.737 | Infra-Rückstände im Grund eines wirtschaftlichen Verdikts |
| `PRAGMA foreign_key_check` | **99** | 71 verwaiste `work_items → tasks`, 28 `tasks → sources`; **`PRAGMA foreign_keys` = 0**, die deklarierten Schlüssel werden also nie durchgesetzt |
| `candidate_qualifications` | **0** | das eigens gebaute Qualifikationsregister ist leer, obwohl Q08–Q10-Evidenz existiert |
| Symbolwerte | 303 | inklusive Nicht-DWX-Altbestand und Zeilen ohne Symbol (Basket) |
| Phasen ohne Gate-Manifest-Eintrag | 1.316 | `OPT_CENSUS` 1.085, `COMPILE_EA` 226, `HARNESS_PP_FIXTURE` 5 — plus 33 Legacy-`P2` |

**Das eigentliche Risiko ist nicht ein einzelner falscher Wert, sondern die Bauform:** die
Wahrheit über eine Zeile entsteht in einer **TEMP-Sicht zur Lesezeit** (`work_items_clean`,
MNT-016), nicht in der Tabelle. Wer diese Sicht nicht installiert, liest 9.381 Zeilen mit einem
anderen Status — zwei Oberflächen können dieselbe Datenbank abfragen, unterschiedliche Zahlen
zeigen und beide „recht haben". Genau deshalb rendert dieser Prototyp ausschließlich über die
Sicht und weist die Quelle im Kopf aus.

**Die schwerwiegendste Lücke ist die fehlende Bindung Lauf → Binärdatei.** Ohne sie kann kein
Verdikt beantworten, welches `.ex5` es erzeugt hat. Das ist nicht nur ein Anzeigeproblem: seit
„rebuilt EX5 = neue Identität ab Q02" ist genau diese Bindung die Voraussetzung dafür, überhaupt
zu wissen, welche PASS-Verdikte nach einer Rebuild-Welle noch gelten.

### Ist SQLite die richtige Lösung?

Ja — die Engine ist nicht das Problem. Ein Host, ein Schreiber, 111 k Zeilen, 404 MB, Vollscan in
1,8 s, WAL, `quick_check ok`. Ein Serverdatenbanksystem würde nichts von dem oben Genannten
beheben, weil keiner der Befunde aus der Engine stammt; sie stammen aus dem **Schema**:
Urteilssemantik liegt in freien Strings, die Taxonomie wird abgeleitet statt gespeichert,
Fremdschlüssel sind deklariert, aber abgeschaltet, und es gibt keine Identitätsspalte für das
Artefakt, das den Lauf erzeugt hat.

Die verhältnismäßige Reparatur ist deshalb **kein Umzug**, sondern drei Ergänzungen am Bestand:

1. **Taxonomie materialisieren** statt zur Lesezeit ableiten (die Sicht bleibt als Prüfer und
   Rückfall) — beseitigt die Klasse „zwei Oberflächen, zwei Wahrheiten".
2. **Artefakt-Identität je Lauf** (`ex5_sha256` verpflichtend beim Schreiben des Ergebnisses) —
   macht F4 überhaupt erst baubar und beantwortet „gilt dieses PASS noch?".
3. **Fremdschlüssel einschalten** und die 99 Waisen bereinigen — `PRAGMA foreign_keys=ON` je
   Verbindung, sonst wächst der Bestand weiter.

Alle drei sind Schreibpfad-Änderungen an der Fabrik und damit **nicht** Teil dieser
Visualisierung. Sie gehören als eigener Auftrag auf das Board; keiner davon ist dringend genug,
den Prototyp aufzuhalten.

## 3 · Nächster Schritt

OWNER sieht sich die Seite an. Danach: Abnahme oder Änderungswünsche, dann Vollausbau in
`render_dashboards.py` mit den Tests aus §11 der Spezifikation.
