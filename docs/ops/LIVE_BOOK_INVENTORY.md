# LIVE_BOOK_INVENTORY — was auf T_Live tatsächlich deployed ist und handelt

**Stand:** 2026-08-19 · Work Order Runde 8 §5.4
**Erzeuger:** `tools/strategy_farm/portfolio/audit_live_book_inventory.py` ·
Artefakt `artifacts/audit_live_book_inventory_20260819.json`
**Rein lesend.** Kein Logout, kein Toggle, keine Konfigurationsänderung.

---

## 0 · Die Zahlen, die bisher gefehlt haben

| Ebene | Zahl | Bedeutung |
|---|---:|---|
| QM5-Binaries in `Experts\Live EAs` | **24** | **das ist die Herkunft der „24 Strategien"** — deployte Dateien |
| EAs mit Per-EA-Log | 26 | inkl. zwei Altlasten |
| **EAs, die aktuell schreiben** (≤ 36 h) | **17** | attached und lebendig |
| **konfigurierte Sleeves** (EA × Symbol) | **20** | drei EAs laufen auf zwei Symbolen |
| EAs, die **jemals** gehandelt haben | 12 | |
| **EAs, die in den letzten 7 Tagen gehandelt haben** | **10** | die tatsächlich arbeitende Menge |
| EAs, die schreiben aber **nie** gehandelt haben | **5** | attached, telemetrisch gesund, null Einstiege |
| stille EAs (Log älter als 36 h) | 9 | |

> **Die „24" stimmen — aber sie zählen Binaries, nicht handelnde Strategien.**
> Handelnd sind **zehn**. Die Differenz ist kein Rundungsfehler, sondern der Unterschied
> zwischen deployed, attached, emitting und trading.

Kontostand aus den `EQUITY_SNAPSHOT`-Zeilen (jeder EA schreibt die **Konto**-Equity, nicht seine
eigene): **99.419,60 $ am 18.08.**, Tages-P&L +218,96 $, Monats-P&L zwischen +34 $ und +155 $ je
nach Lesezeitpunkt. Das Konto liegt knapp unter 100.000 $.

---

## 1 · Die Ist-Aufnahme

**[MESSUNG]** Quelle: `C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\QM5_<id>_*.log` — terminal-lokal,
append-geschrieben, nicht mit der Fabrik geteilt (anders als die `FILE_COMMON`-q08-Streams, die
laut `portfolio_live_forward_from_logs.py` bei allen Live-Sleeves ausschließlich Backtest-Trades
enthalten).

### 1.1 Aktiv und handelnd — zehn

| EA | Symbol | Magic | letzte Aktivität | Einstiege | letzter Trade |
|---|---|---:|---|---:|---|
| 10440 | NDX | 104400003 | vor 1 h | 5 | **19.08. 13:59** |
| 10911 | GDAXI | 109110003 | vor 1 h | 10 | **19.08. 13:59** |
| 13301 | GDAXI | 133010010 | vor 6 h | 18 | **19.08. 08:29** |
| 10706 | GBPUSD | 107060001 | vor 9 h | 5 | 18.08. 09:00 |
| 10403 | XAUUSD | 104030002 | vor 17 h | 36 | 18.08. 22:01 |
| 11132 | SP500 | 111320000 | vor 17 h | 4 | 18.08. 22:00 |
| 11708 | EURUSD | 117080000 | vor 18 h | 6 | 18.08. 21:04 |
| 13213 | USDJPY | 132130000 | vor 18 h | 34 | 18.08. 02:59 |
| 11421 | AUDUSD, EURUSD | 114210000, 114210003 | vor 18 h | 32 | 17.08. 21:04 |
| 1556 | XAUUSD | 15560004 | vor 17 h | 5 | 13.08. 04:47 |

### 1.2 Aktiv, aber seit über einer Woche flach — zwei

| EA | Symbol | Magic | letzter Trade |
|---|---|---:|---|
| 10513 | XAUUSD | 105130003 | **02.08.** |
| 11165 | AUDCAD, EURUSD | 111650000, 111650002 | **06.08.** |

### 1.3 Attached, telemetrisch gesund, **nie gehandelt** — fünf

| EA | Symbol | Magic | Equity-Snapshots | Einstiege |
|---|---|---:|---:|---:|
| 10919 | XTIUSD | 109190001 | 25 | **0** |
| 12567 | XAUUSD, XNGUSD | 125670002, 125670003 | 69 | **0** |
| 12989 | XAUUSD | 129890003 | 31 | **0** |
| 13128 | NDX | 131280000 | 26 | **0** |
| 10939 | GBPUSD | 109390001 | 37 | **0** |

**Das ist der wichtigste Einzelbefund dieser Aufnahme.** Fünf EAs sind seit Wochen attached,
schreiben täglich ihre Equity-Snapshots — und haben in ihrer gesamten Laufzeit **keinen einzigen
Einstieg** erzeugt. Sie belegen Kapitalallokation ohne Beitrag. Ob das ein echtes „kein Signal"
ist (wie bei den 1537-Rescue-Fällen, die als GENUINE no-signal geschlossen wurden) oder ein
Defekt, ist aus dem Log allein nicht entscheidbar und gehört geprüft. → **OQ-19**

### 1.4 Still — neun

| EA | Symbol | letztes Lebenszeichen |
|---|---|---|
| 12969 USDJPY · 1567 EURUSD | | **14.08.** (117 h) |
| 12778 AUDUSD · 13117 EURGBP | | 14.08. |
| **ea_id 0 „unconfigured"** | AUDCAD, AUDUSD, EURGBP, EURUSD, XAUUSD … | 14.08. |
| 10476 USDCAD · 10692 NDX · 10715 USDJPY | | **19.07.** (746 h) |
| 10940 XAUUSD | | **05.07.** (1.081 h) |

**Der Fund in dieser Gruppe: `QM5_0000_unconfigured.log`.** Eine EA-Instanz ist mit `ea_id: 0`
und `magic: 0` initialisiert und hat auf mindestens fünf Symbolen `RNG_SEED_SET` geschrieben.
Mit Magic 0 ist sie weder der Magic-Registry zuzuordnen noch von der Kill-Switch-Logik adressierbar
(`manual_halt_file` wird aus der `ea_id` gebildet). Zuletzt aktiv am 14.08. → **OQ-20**

Die Logdatei enthält außerdem ineinander verschachtelte JSON-Zeilen — mehrere Chart-Instanzen
schreiben gleichzeitig in dieselbe Datei. Der Scanner rettet die Identität per Regex, statt die
Zeilen zu verwerfen; die Zahl der unlesbaren Zeilen steht im Artefakt.

---

## 2 · Abgleich gegen das DRAFT-Manifest vom 26.06.

`portfolio_manifest_tlive_DRAFT_2026-06-26_deploy.json`, Status `DRAFT_FOR_OWNER_APPROVAL`,
sechs Sleeves:

| Manifest-Sleeve | Magic | Risk % | Zustand heute |
|---|---:|---:|---|
| 10440 NDX | 104400003 | 0,052 | **handelt** (19.08.) |
| 10513 XAUUSD | 105130003 | 0,285 | attached, flach seit 02.08. |
| 10692 NDX | 106920005 | 0,071 | **still seit 19.07.** |
| 10940 XAUUSD | 109400003 | 0,223 | **still seit 05.07.** |
| 11132 SP500 | 111320000 | 0,403 | **handelt** (18.08.) |
| 12567 XNGUSD | 125670002 | 0,966 | attached, **nie gehandelt** |

**Zwei von sechs Manifest-Sleeves handeln. Zwei sind seit über einem Monat still.**

Und in die andere Richtung: **14 der 17 aktiven EAs stehen in keinem Manifest.** Magics stimmen
dort, wo beide Seiten dieselbe Zeile kennen — die Magic-Formel `ea_id*10000+slot` hält in allen
geprüften Fällen. Was fehlt, ist nicht die Identität, sondern die **Autorisierung**: für 14
laufende Sleeves existiert kein unterschriebenes Manifest.

> **Damit ist die Frage aus §5.4 beantwortet, und die Antwort ist unbequemer als die Zahl:** das
> Live-Buch ist nicht bloß undokumentiert, es weicht vom letzten dokumentierten Stand in beide
> Richtungen ab. Bei einem Vorfall wäre aus dem Manifest heraus nicht rekonstruierbar, was
> gelaufen ist — aus den Per-EA-Logs dagegen schon, und zwar vollständig.

---

## 3 · Empfehlung

1. **Die Per-EA-Logs sind die belastbare Quelle**, nicht das Manifest und nicht das
   Experts-Verzeichnis. Dieser Scanner sollte als tägliche Aufnahme laufen — er kostet Sekunden
   und ist rein lesend.
2. **Ein aktuelles Manifest aus dem Ist-Zustand erzeugen und OWNER zur Unterschrift vorlegen.**
   Das ist keine Änderung am Live-Buch, sondern die Dokumentation dessen, was ohnehin läuft.
3. **Die fünf Nie-Händler prüfen** (OQ-19) — 5 von 20 Sleeves ohne einen einzigen Einstieg ist
   entweder ein Defekt oder eine Fehlallokation, und beides kostet.
4. **`ea_id 0` klären** (OQ-20) — eine Instanz ohne Magic ist außerhalb jeder Kontrolle.
5. **Die vier seit Juli stillen EAs** aus dem Terminal nehmen oder als bewusst ruhend dokumentieren.

**Keine dieser Maßnahmen ist ausgeführt.** T_Live ist unverändert; dieses Dokument ist die
Bestandsaufnahme, zu der die Directive beauftragt hat.
