# SYMBOL_RANKING_PAIRED — die gepaarte Gegenprobe, und was von der Liste übrig bleibt

**Stand:** 2026-08-19 · Work Order Runde 10 §1
**Kontrollgruppe:** die 75 EAs, die über alle 37 Symbole gelaufen sind (2.775 Paare) —
bei ihnen ist die EA-Population je Symbol identisch.

---

## 0 · Die Antwort, und sie ist unbequemer als erhofft

> **Ein Symbol ist bewiesen: XAUUSD.** Gepaart 37,9 % gegen einen Bestandsdurchschnitt von 9,1 %,
> und sein Konfidenzband überlappt keines der schwachen Symbole.
>
> **Die Mitte der Liste zerfällt.** GDAXI fällt von 14,1 % auf **6,9 %**, XTIUSD von 12,6 % auf
> **8,3 %** — ihre ungepaarten Werte kamen zu erheblichem Teil aus der EA-Population, nicht aus dem
> Symbol. **USDJPY steigt** von 7,0 % auf 10,3 % und schlägt beide.
>
> **Die Sieben-Symbol-Liste in ihrer Fassung von gestern ist damit widerlegt.** Die korrigierte
> Fassung steht in §3.

---

## 1 · Die gepaarte Tabelle

**[MESSUNG]** Q04-Durchlass, nur auf den 75 Alles-Läufern, gegen den Rest der Flotte:

| Symbol | Klasse | **gepaart n** | pass | **gepaart** | Rest n | Rest | Δ |
|---|---|---:|---:|---:|---:|---:|---|
| **XAUUSD** | Metall | 29 | 11 | **37,9 %** | 569 | 20,0 % | **+17,9** |
| WS30 | Index | 25 | 5 | 20,0 % | 158 | 14,6 % | +5,4 |
| SP500 | Index | 33 | 5 | 15,2 % | 244 | 15,2 % | 0,0 |
| XAGUSD | Metall | 36 | 5 | 13,9 % | 34 | 14,7 % | −0,8 |
| NDX | Index | 33 | 4 | 12,1 % | 476 | 13,2 % | −1,1 |
| **USDJPY** | **FX** | 39 | 4 | **10,3 %** | 628 | 6,8 % | **+3,5** |
| **GBPJPY** | **FX** | 35 | 3 | **8,6 %** | 122 | 2,5 % | **+6,1** |
| **XTIUSD** | Energie | 36 | 3 | **8,3 %** | 234 | 13,2 % | **−4,9** |
| **GDAXI** | Index | 29 | 2 | **6,9 %** | 353 | 14,7 % | **−7,8** |
| XNGUSD | Energie | 34 | 2 | 5,9 % | 54 | 11,1 % | −5,2 |
| EURUSD · GBPUSD · AUDUSD … | FX | 27–42 | 0–2 | 0–6,7 % | | | |
| **UK100** | Index | 30 | **0** | **0,0 %** | 50 | 6,0 % | −6,0 |
| acht FX-Symbole | FX | 29–32 | **0** | **0,0 %** | | | |

**Antwort auf §1.2 — nein, die Rangfolge hält nicht.** Oben und unten ja, die Mitte nicht.

## 2 · Was statistisch trägt, und was nicht

**[MESSUNG] Wilson-Bänder auf der gepaarten Messung:**

| Symbol | n | Quote | 95 %-Band |
|---|---:|---:|---|
| **XAUUSD** | 29 | 37,9 % | **[22,7 % – 56,0 %]** |
| WS30 | 25 | 20,0 % | [8,9 % – 39,1 %] |
| SP500 | 33 | 15,2 % | [6,7 % – 30,9 %] |
| XAGUSD | 36 | 13,9 % | [6,1 % – 28,7 %] |
| NDX | 33 | 12,1 % | [4,8 % – 27,3 %] |
| USDJPY | 39 | 10,3 % | [4,1 % – 23,6 %] |
| GDAXI | 29 | 6,9 % | [1,9 % – 22,0 %] |

> **Nur XAUUSD ist von der Nullgruppe getrennt.** Sein unteres Band (22,7 %) liegt über den oberen
> Schranken aller Nullsymbole (~11 %). **Alles zwischen WS30 (20,0 %) und XNGUSD (5,9 %) ist bei
> diesen Fallzahlen nicht unterscheidbar** — die scheinbare Rangfolge dort ist Rauschen.

Das ist die ehrliche Fassung: die gepaarte Probe hat **einen** Befund bewiesen und die übrige
Rangfolge auf „plausibel, unbewiesen" zurückgestuft.

## 3 · Die korrigierte Liste

| Rang | Symbole | Grundlage |
|---|---|---|
| **1 · bewiesen** | **XAUUSD** | gepaart 37,9 %, Band getrennt; in beiden Populationen führend |
| **2 · konsistent, unbewiesen** | **WS30, SP500, XAGUSD, NDX** | gepaart 12–20 %, ungepaart 13–15 % — beide Messungen stimmen überein |
| **3 · beobachten** | **USDJPY**, GBPJPY | die einzigen FX-Symbole, die gepaart **steigen**; USDJPY ist in beiden Fassungen bestes FX |
| **4 · herabgestuft** | **GDAXI, XTIUSD, XNGUSD** | fallen gepaart um die Hälfte — ihr ungepaarter Wert war Population, nicht Symbol |
| **5 · zurückgestellt** | die acht Nullsymbole, **UK100**, übrige FX | siehe §4 |

**Antwort auf §1.4:** die Steuerung kommt aus der gepaarten Messung. Konkret heißt das gegenüber
gestern: **GDAXI und XTIUSD verlassen die bevorzugte Gruppe, USDJPY rückt hinein.**

**Und die praktische Konsequenz ist unangenehm:** die bevorzugte Gruppe schrumpft auf fünf Symbole,
von denen XAUUSD und XAGUSD zusammen nur **316 freie Paare** haben. Die Umsteuerung kauft damit
noch weniger Zeit als in `ALLOCATION_SHIFT.md` gerechnet — der Vorrat der Ränge 1 und 2 beträgt
XAUUSD 250 + XAGUSD 66 + NDX 200 + WS30 171 + SP500 142 = **829 Paare**, rund **39 Stunden**.

## 4 · Die Nullsymbole — schwach einzeln, stark gepoolt

Deine Einordnung ist richtig und ich übernehme sie: null von 40 ist schwächer, als es klingt.

**[MESSUNG] Über den gesamten Bestand, nicht nur die gepaarte Gruppe:**

| Symbol | n | Passes | obere Schranke |
|---|---:|---:|---:|
| AUDNZD · CADCHF · NZDJPY | je 42 | 0 | 8,4 % |
| GBPCHF · NZDCHF | je 41 | 0 | 8,6 % |
| NZDCAD | 39 | 0 | 9,0 % |
| EURCHF · GBPCAD | je 38 | 0 | 9,2 % |
| **gepoolt** | **323** | **0** | **1,18 %** |

**Zwei Lesarten, und beide gehören ins Dokument:**

* **Einzeln** liegt die obere Schranke bei 8–9 %. Bei einer wahren Quote von 5 % wäre null in
  40 Läufen keine Überraschung, und bei 28 FX-Symbolen wäre es mehrfach zu erwarten. **Kein
  einzelnes dieser Symbole ist als schlecht bewiesen.**
* **Gepoolt** — unter der Annahme, dass die acht eine gemeinsame Rate teilen — liegt die obere
  Schranke bei **1,18 %**. Und sie sind **in beiden Populationen null**: gepaart (n ≈ 30 je Symbol)
  wie ungepaart.

> **Für die Zurückstellung reicht das, für die Streichung nicht** — genau wie in der Work Order
> formuliert. Sie bleiben in der Warteschlange, hinten.

**UK100 ist der interessantere Fall:** 3/80 = 3,8 % über den Bestand [1,3 % – 10,5 %], **0/30
gepaart**. Ein Index, der sich wie schwaches FX verhält. Er bleibt als Gegenbeispiel im Dokument,
weil er der beste einzelne Beleg dafür ist, dass die Anlageklasse die falsche Abstraktionsebene war.

## 5 · Die Alles-Läufer sind eine besondere Sorte — und zwar eine schlechtere (§1.5)

**[MESSUNG]**

| Population | Q04-Durchlass |
|---|---:|
| die 75 Alles-Läufer | **65/1.190 = 5,5 %** [4,3 % – 6,9 %] |
| der Rest der Flotte | **509/5.579 = 9,1 %** |

**Die Kontrollgruppe ist unterdurchschnittlich**, und zwar deutlich. Das war zu erwarten: ein EA,
der über alle 37 Symbole gefahren wird, ist genau der, dessen Karte kein Universum erklärt hat —
also tendenziell die weniger sorgfältig spezifizierte Sorte.

**Was das für die Messung bedeutet, in beide Richtungen:**

* **Die interne Gültigkeit ist unberührt.** Innerhalb der Gruppe ist die EA-Population je Symbol
  identisch; der Symbolvergleich ist sauber.
* **Die absoluten Niveaus sind nicht übertragbar.** Dass XAUUSD hier 37,9 % erreicht, heißt nicht,
  dass die Flotte auf XAUUSD 37,9 % erreicht — es heißt, dass **schlechte EAs auf XAUUSD viermal
  häufiger durchkommen als im Mittel über alle Symbole.**

Das macht den XAUUSD-Befund eher stärker als schwächer: der Symbolvorteil ist so groß, dass er
eine unterdurchschnittliche EA-Population über den Flottenschnitt hebt.

## 6 · Was ich daraus nicht ableite

* **Nicht, dass GDAXI und XTIUSD schlecht sind.** Ihre gepaarten Bänder ([1,9 %–22,0 %] und
  [2,9 %–21,8 %]) schließen ihre ungepaarten Werte ein. Sie sind **unbewiesen**, nicht widerlegt.
* **Nicht, dass USDJPY gut ist.** 4 von 39 mit Band [4,1 %–23,6 %] ist ein Hinweis, kein Beleg.
* **Nicht, dass die Fallzahlen reichen.** 25 bis 42 Läufe je Symbol sind wenig. Die saubere
  Fortsetzung wäre, die gepaarte Gruppe zu vergrößern — was genau das ist, was die Umsteuerung
  ohnehin täte, wenn sie Symbole statt Karten steuert.
