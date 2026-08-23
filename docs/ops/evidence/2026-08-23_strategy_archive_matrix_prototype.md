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

## 4 · Nachtrag 2026-08-23 abends — Englisch, Relikt-Symbole, Detailseiten

### 4.1 Oberfläche auf Englisch

Matrix und Detailseiten sind vollständig englisch (OWNER 2026-08-23). Die Gate-Namen kommen
unverändert aus dem Gate-Manifest, die Verdikt-Token bleiben die gespeicherten.

### 4.2 Relikt-Symbole entfernt — mit korrigiertem Umfang

Auftrag: „Symbole ohne `.DWX` überall raus, das sind Relikte." **Gemessen trifft das 228 von 995
Nicht-DWX-Zeilen.** Der Rest ist keine Altlast:

| Klasse | Symbolwerte | Zeilen | jüngste Aktivität |
|---|---:|---:|---|
| **Relikte** (nackte Ticker) | 9 | **228** | 2026-06-21 (geschlossen) |
| logische Basket-Symbole | 234 | 767 | **2026-08-23 (heute)** |
| leeres Symbol (Basket-Host) | 1 | 226 | **2026-08-23 (heute)** |

Die 9 Relikte: GBPUSD 110 · USDJPY 90 · EURJPY 9 · GBPJPY 9 · AUDUSD 4 · EURUSD 3 ·
NZDUSD/USDCAD/USDCHF je 1. **196 davon tragen bereits `OBSOLETE_NON_DWX_SYMBOL`**, die übrigen 32
`INFRA_FAIL`/`INVALID` — kein einziges wirtschaftliches Urteil darunter. Ein wörtlich ausgeführtes
„alles ohne .DWX löschen" hätte **993 Zeilen laufender Basket-Arbeit vernichtet**, davon Zeilen
von heute.

Umgesetzt ist deshalb die **Verdrängung aus der Darstellung**, nicht die Löschung: der Renderer
klassifiziert `dwx` / `basket` / `relic` und schließt nur die Relikt-Klasse aus — aus `work_items`
und aus den Karten-Zielsymbolen gleichermaßen (7 Karten trugen 27 Nicht-DWX-Ziele inklusive
`TBD_*`-Platzhalter, die Q02-Löcher auf nicht existierenden Symbolen erfunden haben). Die Fußzeile
nennt jedes ausgeschlossene Symbol samt Zeilenzahl.

**Keine Datenbankzeile wurde gelöscht.** Verdikte zu löschen ist ROT-Zone; für die 228 Zeilen
liegt eine ausdrückliche OWNER-Freigabe auf den korrigierten Umfang noch nicht vor.

### 4.3 Detailseite je Strategy Card

`strategy_detail/<ea>.html`, verlinkt aus der ersten Spalte der Matrix.

| Größe | Wert |
|---|---|
| Seiten | **2.984** (62,3 MB gesamt, ~21 KB je Seite) |
| Erzeugung | 27,8 s + 21,6 s Report-Index |
| Work Items dargestellt | 110.077 (**alle** Versuche, auch superseded und verbrannt) |
| davon mit nativem MT5-Report auf Platte | **17.397 (15,8 %)** |
| Seiten ohne Strategy Card auf Platte | **391 (13,1 %)** |

Inhalt: Kopfdaten aus dem Karten-Frontmatter (Timeframe, Zielsymbole, erwartete Frequenz,
erwarteter PF/DD, Risikoklasse, G0-Status), Quellenzitat, die **vollständige Karte gerendert**
(Source, Edge thesis, Rules, dokumentierte Abweichungen, GAPs, Kosten/Compliance) und darunter
eine Tabelle **jedes** gespeicherten Laufs mit Datum, Gate, Symbol, Verdikt, Taxonomie und
Direktlink auf `report.htm` — den nativen MetaTrader-5-Report.

**Report-Abdeckung ehrlich ausgewiesen:** der Index über `D:\QM\reports` findet 46.822
Reportdateien zu 17.471 Work Items. Ältere Läufe wurden von der Plattenpflege entfernt; die
Zeile sagt dann „report purged" statt ins Leere zu verlinken. Abdeckung nach Alter gemessen:
jüngste 500 Zeilen 97 %, letzte 30 Tage 95 %, vor dem 01.06. **0 %**.

**Befund nebenbei:** die 3.191 bestehenden `ea_*.html`-Detailseiten enthalten **keine**
Strategieerklärung (0 Treffer für Mechanism/Card/Quelle) und verlinken bei QM5_13036 genau
3 von 21 Läufen. Der Vollausbau sollte die neue Detailseite in `render_dashboards.py`
übernehmen, statt beide Seiten nebeneinander zu pflegen.

## 5 · Ausgeführt 2026-08-23 abends — Relikt-Löschung und Aufbewahrungsbefund

### 5.1 Die 228 Relikt-Zeilen sind gelöscht (OWNER-Freigabe auf den korrigierten Umfang)

| Schritt | Ergebnis |
|---|---|
| Vollständige Zeilen als Evidenz gesichert | `docs/ops/evidence/2026-08-23_relic_symbol_purge_rows.json` (498 KB, 228 Work Items + 199 `ea_metrics`) |
| Datenbanksicherung vor dem Eingriff | `D:\QM\backups\farm_state_20260823T114644Z_pre_relic_purge.sqlite` (366 MB, `VACUUM INTO`) |
| Gelöscht | **228** `work_items` + **199** `ea_metrics` |
| `work_items` gesamt | 111.624 → 111.396 (Delta exakt 228) |
| Relikt-Zeilen übrig | **0** |
| Nicht-DWX-Zeilen übrig (Basket + leeres Symbol) | **996 — unangetastet** |

Vorabprüfungen im Skript, die den Lauf sonst abgebrochen hätten: Umfang exakt 228, alle Zeilen
terminal (`failed`), kein wirtschaftliches Verdikt in der Menge (196 `OBSOLETE_NON_DWX_SYMBOL`,
26 `INFRA_FAIL`, 6 `INVALID`). Keine Waisen erzeugt: die Zeilen hatten keine Holds, keine
Transitions, keine Kinder, keine Qualifikationseinträge.

### 5.2 Werden alte Backtests automatisch gelöscht? — nein, und genau das ist das Problem

Die dokumentierten Aufräumjobs löschen **ausschließlich MT5-Journale** (`*.log`) und halten
`report.htm`, `summary.json` und `.set` ausdrücklich fest:

| Job | Auslöser | löscht |
|---|---|---|
| `reports_log_purge.ps1` (`QM_StrategyFarm_ReportsLogPurge_12h`) | alle 12 h | `*.log` älter als 12 h, plus Größenbudget |
| `prune_workitem_logs.py` (`QM_WorkItemLogPruner_Daily_0310`) | täglich 03:10 | `*.log` terminaler Work Items |
| `tester_cache_purge.ps1` | alle 10 min, unter 150 GB frei | nur MT5-Tester-Caches, **nie** `D:\QM\reports` |

**Gemessen sieht es trotzdem anders aus.** Es existiert **kein einziges Report-Verzeichnis von
vor dem 07.07.2026**: 20.057 Verzeichnisse, 69 GB, ältestes 2026-07-07. Stichprobe nach
Work-Item-ID: Mai 0/300, Juni 0/300, Juli 87/300, August 240/300.

**Ursache sind die einmaligen manuellen Plattenaufräumungen der D:-Krisen** (10.06.: 405 GB,
22.07.: 153,7 GB reklamiert) — ganze Bäume, nicht die dokumentierte Aufbewahrungsregel.

Aktuelles Volumen: **51.638 `report.htm`/`.html` = 16,78 GB** für rund 6,7 Wochen, also etwa
2,5 GB/Woche. Die Journale, die die Krisen ausgelöst hatten, liegen dank Purge bei nur 1,80 GB.

**Der eigentliche Defekt ist, dass es für `report.htm` gar keine Aufbewahrungs-ENTSCHEIDUNG
gibt.** Die Artefakte überleben zufällig und verschwinden zufällig. Eine Archivseite kann damit
keine Evidenzspur versprechen, die sie nicht kontrolliert. Beauftragt als `b24d7875`
(`QM-TODO-20260823-506`) mit vier Optionen; Empfehlung: Meritzeilen (PASS / Buchkandidaten)
dauerhaft halten, gewöhnliche FAIL-Läufe altern lassen, den behaltenen Bestand komprimieren.

### 5.3 Detailseite ersetzt `ea_*.html`

OWNER-Entscheid 2026-08-23. Beauftragt als `0b6f3039` (`QM-TODO-20260823-505`): der Prototyp-Code
(`render_detail`, `build_report_index`, `md_to_html`) wandert nach `render_dashboards.py`, die
`ea_<id>.html`-URL bleibt erhalten oder wird umgeleitet, weil andere Oberflächen darauf zeigen.

## 6 · Nachtrag: Sprache und Website (OWNER 2026-08-23, spät)

### 6.1 „Nicht durchgängig englisch" — der Renderer war nicht schuld

Gemessen über die freigegebenen Karten: **2.696 von 3.271 (82 %)** tragen deutsche
Abschnittsüberschriften.

| Überschrift | Karten |
|---|---:|
| `Quelle` | 2.694 |
| `Mechanik` | 2.681 |
| `Pipeline-Verlauf` | 2.668 |
| `Verwandte Strategien` | 2.176 |
| `R1-R4 Bewertung` (beide Strich-Varianten) | 2.660 |

Das **v2-Template ist englisch** (`framework/templates/strategy_card_v2.md`: Source-defined
rules, QM interpretations, Framework execution overrides …). Die deutschen Überschriften
entstehen also beim **Schreiben** der Karten, nicht beim Rendern und nicht durch das Template.

**Sofort behoben:** `archive_matrix.normalise_heading()` übersetzt den bekannten Satz auf
Überschriften und Tabellenköpfen, exakte Treffer, Unbekanntes bleibt unangetastet.

**Bewusst nicht getan:** die Karten umschreiben. `strategy_card_v3` ist inhaltsadressiert
(`source_sha256`, Fingerprint) — 2.696 Evidenzdokumente zu editieren würde Duplikaterkennung und
Evidenzkette für einen kosmetischen Gewinn zerreißen. Die dauerhafte Reparatur gehört an den
Karteneingang (`fe6e8a54`).

### 6.2 Weg auf die Website

`public-data/strategy-archive.json` existiert bereits — **Schema v1, 3.557 Einträge, aber nur
`slug`, `source`, `visibility`, `last_updated_utc`**. Eine Namensliste ohne Gate-Daten, exportiert
von `scripts/export_public_snapshot.ps1` (Task `QM_Public_Snapshot_Hourly`), geprüft von
`validate_public_snapshot.ps1`.

Der Ausbau braucht Schema v2 plus eine **öffentliche Projektion** aus `archive_matrix.collect()`.
Harte Auflagen stehen im Auftrag `2b95f500`: keine `file://`-Links (die interne Detailseite ist
voll davon), keine VPS-Pfade, keine Work-Item-UUIDs, `visibility` respektiert, Snapshot-Guard
bleibt fail-closed — die Website-Redaktion hat am 21.08. 2.334 Pfade und Mailadressen geleakt,
weil die Fixtures nur Backslashes kannten.

**Offen beim OWNER:** wie viel Verdikt-Detail überhaupt öffentlich wird — (a) nur Abdeckung,
(b) PASS/FAIL ohne Zahlen, (c) volles Detail. Empfehlung (a).

## 3 · Nächster Schritt

OWNER sieht sich die Seite an. Danach: Abnahme oder Änderungswünsche, dann Vollausbau in
`render_dashboards.py` mit den Tests aus §11 der Spezifikation.
