# STRATEGY_FILES_INVENTORY — was auf dem VPS liegt und was davon neu ist

**Stand:** 2026-08-19 · Work Order Runde 7 §3
**Inventar und Bewertung. Nichts eingereiht, nichts portiert, nichts gelöscht.**

---

## 0 · Die eine Zahl

> **Rund 70 distinkte, nicht-ML, nicht-ICT/SMC Strategie-Kandidaten liegen als MQL5-Quelltext auf
> dem Rechner, die die Fabrik nie als Quelle gesehen hat — und ein erheblicher Teil davon dürfte
> unsere eigene frühere Produktion sein, nicht fremdes Angebot.**
>
> **Die größere Zahl liegt woanders: 428 fertig kompilierte EAs im Repo haben die Fabrik nie
> betreten.** Das ist Angebot ohne jede Portierung.

---

## 1 · Was auf dem Desktop liegt — nicht das, wonach die Frage klang

Der Desktop enthält **keine Strategiedateien im Sinne von Quelltext.** Er enthält zwei
**Strategie-Karten-Dokumente** und Betriebsartefakte:

| Datei | Größe | Stand | Art |
|---|---:|---|---|
| `Strategy_Cards_Overview.md` | 34,8 KB | 15.08. | **100 Strategiekarten**, IDs QM5_30001–41012 |
| `Strategy_Cards_Overview_2.md` | 25,9 KB | 18.08. | **20 Strategiekarten**, IDs QM5_42001–44004 (Master Suite 2: Gold Reaper, UBS, Gold Breakout Engine) |
| `FTMO_Factory_Hindernisse_Analyse_2026-08-16.md` | 22,5 KB | 16.08. | Analyse, keine Strategie |
| `codex session.md`, `✳ Factory CEO.txt`, Verknüpfungen, `.bat`, ein Screenshot | | | Betrieb |

**Dedupe der 120 Karten-IDs gegen die Fabrik:**

| | |
|---|---|
| IDs in den beiden Dokumenten | **120** |
| davon bereits in `work_items` | **37** |
| davon mit gebautem EA-Verzeichnis | **82** |
| **noch nie eingereiht** | **83** |

Die Karten sind also größtenteils schon **gemünzt** (82 EA-Verzeichnisse), aber nur zu einem Drittel
**eingereiht**. Der Engpass liegt nicht bei der Ideenfindung.

## 2 · Wo der Quelltext wirklich liegt

| Ort | Dateien | Größe | wesentliche Formate |
|---|---:|---:|---|
| `C:\Users\Administrator\Downloads` | 4.665 | 3.685 MB | 388 `.mq5` · 431 `.ex5` · 517 `.mqh` · 530 `.set` · **341 PDF (1.584 MB Literatur)** · 266 `.onnx` |
| `C:\Users\Administrator\Dropbox` | 2.587 | 350 MB | 282 `.mq5` · 291 `.ex5` · 462 `.mqh` · 215 `.onnx` |

**Dropbox spiegelt Downloads weitgehend** — von 318 inhaltlich verschiedenen `.mq5` liegen **253 in
beiden** Wurzeln. Der Vergleich läuft über **SHA-256 des Dateiinhalts**, nicht über Namen (§3.3):
Namen sind hier unbrauchbar, weil dieselbe Datei mehrfach mit Suffixen wie `(1)`, `(2)` vorliegt.

### Dedupe gegen die Fabrik

| | |
|---|---|
| `.mq5` gescannt | 670 |
| inhaltlich distinkt | **318** |
| **byte-identisch zu einer Fabrikquelle** | **0** |

Keine einzige dieser Dateien ist als Quelle in die Fabrik übernommen worden. Das heißt **nicht**, dass
die Ideen neu sind — nur, dass die Dateien es sind.

### Klassifikation der 318

| Art | Anzahl |
|---|---:|
| **EA** (`OnTick` + Handelsaufrufe) | **165** |
| Indikator (`OnCalculate`) | 70 |
| include-artig / sonstiges | 47 |
| Script | 21 |
| MQL5-Standardbibliothek / Tests | 15 |

### Die 165 EAs, gefiltert nach unseren eigenen Regeln

| Filter | Anzahl | Begründung |
|---|---:|---|
| **ML-markiert** (`onnx`, `tensorflow`, `keras`, `neural`) | **58** | **Hard Rule: keine ML-Bibliotheken in V5-EAs.** Ausgeschlossen, nicht bewertet. Dominiert von der `ICT_ML_*`-Familie |
| **ICT/SMC-Familie** | **25** | geschlossene Forschungslinie (ICT/SMC retire, 16.07.). Nicht wieder aufmachen |
| **verbleibend** | **82** | → nach Einklappen von Symbol- und Timeframe-Varianten: **~70 distinkte Strategie-Stämme** |

**Und hier die Einschränkung, die die Zahl kleiner macht, als sie aussieht:** unter den 70 Stämmen
dominieren Namen wie `FTMO_SM_003_RoundNumber`, `FTMO_SM_007_MondayRange`, `QM_SilverBullet`,
`QM_AsianBreakout`, `QM_Donchian` — **das ist mit hoher Wahrscheinlichkeit unsere eigene frühere
Produktion**, exportiert und nie zurückgeführt. „Nicht byte-identisch zur Fabrik" heißt nicht
„fremde Idee".

**Ehrliche Bewertung der Verwertbarkeit:**

| Gruppe | Anzahl | Aufwand |
|---|---:|---|
| **sofort einreihbar** | **0** | keine Datei ist QM5-konform (Magic, `qm_*`-Inputs, Kartenbindung, Stream-Emitter) |
| **Portierung ins V5-Framework** | ~70 Stämme | je Datei: Kartenspezifikation, Neuimplementierung gegen `QM_Common.mqh`, Magic, Setfile — **Größenordnung ein Build-Ticket je Stamm**, also derselbe Aufwand wie eine Neuentwicklung aus einer Karte |
| **nur als Idee verwertbar** | 341 PDFs + 70 Indikatoren | Mining-Aufwand, kein Portierungsaufwand |
| **unbrauchbar / ausgeschlossen** | 58 ML + 15 Stdlib + 21 Scripts | |

## 3 · Der größere Fund liegt im Repo, nicht im Download-Ordner

**[MESSUNG]** 3.361 distinkte EA-IDs haben eine kompilierte `.ex5`. **428 davon waren nie in
`work_items`.**

| Baumonat | Anzahl | Einordnung |
|---|---:|---|
| 2026-06 | 355 | Familien `tv` 35, `carter` 35, `tc` 20, `robo` 19; Schwerpunkt ID 11000–11999 |
| 2026-07 | 13 | |
| **2026-08** | **60** | davon **56 als `build_ea`-Ticket in REVIEW** — vor meinem Ventil |

**Das ist Angebot, das keine Portierung braucht.** Es ist bereits QM5-konform, kompiliert und
kartengebunden.

**Warum es nicht läuft, ist zweigeteilt:**

* Die **60 aus dem August** hängen am Review-Ventil. Das ist meine Kapazität, nicht die der Fabrik.
* Die **355 aus dem Juni** sind ungeklärt. Ein Hinweis: die Stichproben `QM5_1003`, `QM5_10063`,
  `QM5_11400` stehen **nicht in der Magic-Registry** (16.083 aktive, 1.451 reservierte, 31 retirierte
  Zeilen) — ohne reservierte Magic ist eine Zeile nicht dispatchbar. Das wäre eine vollständige
  Erklärung, ist aber an **drei** Stichproben geprüft, nicht am Satz.

**„Nie eingereiht" heißt nicht „bereit zum Einreihen".** Vor einer Freigabe gehört je EA geprüft:
Magic vorhanden, Karte gültig, nicht durch eine neuere Variante ersetzt. Diese Prüfung ist nicht
Teil dieses Inventars.

## 4 · Antwort auf §3.5

> **Neue, verwertbare Kandidaten, die die Fabrik noch nicht gesehen hat:**
>
> * **aus den externen Quelltexten: ~70 Stämme**, jeder mit vollem Portierungsaufwand, ein
>   erheblicher Teil davon vermutlich eigene Altproduktion → **realistisch eher zweistellig niedrig**
> * **aus dem Repo: 428 kompilierte EAs**, ohne jeden Portierungsaufwand, davon **60 frisch und
>   56 hinter dem Review-Ventil**
> * **aus den Karten: 83 Karten-IDs**, davon 82 bereits gebaut
>
> **Der billigste Kandidat ist der bereits gebaute.** Die 428 sind um Größenordnungen näher an Q02
> als alles im Download-Ordner.
