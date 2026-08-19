# EV_FUNDED_ACCOUNT — was ein finanziertes Konto wert ist, bevor es bricht

**Snapshot:** `3472a5d2e1b5` · **Stand:** 2026-08-19 · Work Order Runde 7 §1
**Erzeuger:** `tools/strategy_farm/portfolio/audit_ev_funded_account.py` ·
Artefakt `artifacts/audit_ev_funded_account_20260819.json`

---

## 0 · Die Antwort in einem Satz

> **Ja — und zwar deutlich, aber nur bei niedrigem Sizing: bei 0,44×–0,50× liegt die
> Break-even-Gebühr je Versuch zwischen 15.000 und 26.000 $, und zwar auf *beiden* Messbasen. Bei
> 0,85×–1,00× fällt sie unter der pessimistischen Basis auf 224 $ bzw. 66 $ und der Erwartungswert
> kippt.**

Damit ist D-9 beantwortet, und die Antwort ist unbequemer als die Frage: **die 80-%-Bar war nicht nur
die falsche Zielgröße — sie hat auch am falschen Ende optimiert.** Wer die Bestehensquote maximiert,
sizt hoch. Wer den Ertrag maximiert, sizt niedrig, weil nach der Finanzierung nur noch die
Überlebensdauer zählt.

---

## 1 · Das Modell, und was daran gemessen statt angenommen ist

```
EV = 0,80 × akkumulierter Gewinn bis zum ersten Bruch − Gebühr × E[Versuche]
```

**Gewinnbeteiligung 80 % ist verifiziert** (`docs/ops/evidence/2026-07-27_ftmo_phase2_and_funded_rules.md`,
aus FTMOs eigener FAQ; 90 % unter dem Scaling Plan). **Die Challenge-Gebühr ist nirgends im Bestand
hinterlegt** — sie wird deshalb nicht erfunden, sondern als Parameter geführt, und ich nenne die
**Break-even-Gebühr**. Das ist die Zahl, die OWNER in einer Minute gegen die Preisliste hält.

**Zwei Dinge sind gemessen statt modelliert:**

1. **Die Lebensdauer.** Nicht geometrisch aus einer Bruchrate, sondern **vorwärts durch die echte
   Reihe**: von jedem der 50 Fensterstarts läuft ein finanziertes Konto weiter, bis es tatsächlich
   bricht. Damit ist die serielle Korrelation drin, statt wegangenommen zu werden.
2. **Die Auszahlungskonvention ist konservativ.** Gewinn wird alle 60 Tage entnommen, die Equity
   fällt auf den Ausgangsstand zurück, und die −10-%-Grenze bezieht sich immer auf diesen. Belassener
   Gewinn wäre ein Polster und würde die Lebensdauer verlängern. **Wenn das Konto in Wirklichkeit
   länger lebt, dann länger als hier.**

## 2 · Ergebnis

**Schlusskursbasis** (optimistische Schranke — kein Intraday-Ausschlag über den Tagesschluss hinaus):

| Sizing | P1 | finanziert | E[Versuche] | Überlebensdauer Median | Auszahlung Ø | **Break-even-Gebühr** |
|---:|---:|---:|---:|---:|---:|---:|
| 0,44× | 50 % | 24 % | 4,17 | **625 d** | 91.801 $ | **22.032 $** |
| 0,50× | 56 % | 34 % | 2,94 | 446 d | 77.216 $ | **26.253 $** |
| 0,60× | 60 % | 38 % | 2,63 | 330 d | 67.994 $ | **25.838 $** |
| 0,85× | 78 % | 48 % | 2,08 | 164 d | 32.927 $ | 15.805 $ |
| 1,00× | 78 % | 52 % | 1,92 | **92 d** | 22.742 $ | 11.826 $ |

**Überlappungsbeschränkter Intraday-Boden** (pessimistische Schranke):

| Sizing | P1 | finanziert | E[Versuche] | Überlebensdauer Median | Auszahlung Ø | **Break-even-Gebühr** |
|---:|---:|---:|---:|---:|---:|---:|
| 0,44× | 50 % | 24 % | 4,17 | 433 d | 62.826 $ | **15.078 $** |
| 0,50× | 56 % | 32 % | 3,12 | 274 d | 48.609 $ | **15.555 $** |
| 0,60× | 48 % | 24 % | 4,17 | 90 d | 13.278 $ | 3.187 $ |
| 0,85× | 18 % | 10 % | 10,00 | 8 d | 2.235 $ | **224 $** |
| 1,00× | 10 % | 6 % | 16,67 | 4 d | 1.100 $ | **66 $** |

## 3 · Was daran robust ist — und das ist der eigentliche Befund

Die gesamte Auditserie hat darunter gelitten, dass Schlusskurs und Intraday-Boden bei jedem Sizing
über 0,60× um Größenordnungen auseinanderliefen. **Hier tun sie es nicht:**

> **Bei 0,44× und 0,50× sagen beide Messbasen dasselbe: eine Break-even-Gebühr im Bereich von
> 15.000 bis 26.000 $.** Zwischen den Schranken liegt kein Vorzeichenwechsel, keine Größenordnung,
> keine Entscheidung.

Das ist die **erste Aussage dieser Serie, die die Intraday-Unsicherheit überlebt.** Alles andere —
Bestehensquote, Obergrenze, Sizing-Plateau — hing an der Frage, welche Kurve stimmt. Diese nicht.

Ab 0,60× beginnt die Divergenz (25.838 $ gegen 3.187 $), und bei 0,85× ist sie total (15.805 $ gegen
224 $). **Die Sizing-Empfehlung aus rev6 — 0,50× — wird durch die Ertragsrechnung unabhängig
bestätigt**, aus einem völlig anderen Grund: dort ist nicht nur die Messung eindeutig, dort ist auch
der Ertrag maximal.

## 4 · Die Unabhängigkeitsannahme — geprüft, und sie hätte in die falsche Richtung geirrt

§1.3 verlangte, den Faktor zu nennen, um den serielle Korrelation die Lebensdauer senkt. Gemessen,
indem die geometrische Erwartung (60 Tage / Fenster-Bruchrate) gegen die vorwärts gemessene
Lebensdauer gestellt wird:

| Sizing | geometrisch erwartet | tatsächlich gemessen (Median) | Faktor |
|---:|---:|---:|---:|
| 0,44× | 3.000 d | 625 d | **4,8× kürzer** |
| 0,60× | 1.000 d | 330 d | **3,0× kürzer** |
| 1,00× | 158 d | 92 d | 1,7× kürzer |

**Die Annahme unabhängiger Fenster hätte die Lebensdauer um das Drei- bis Fünffache überschätzt.**
Verluste kommen geklumpt; ein Konto, das in eine schlechte Phase gerät, überlebt sie selten. Die
Zahlen in §2 sind die gemessenen, nicht die geometrischen — sie tragen den Abschlag bereits.

## 5 · Was die Rechnung **nicht** sagt

* **Nicht, dass das Buch die 80-%-Bar erreicht.** Tut es nicht, und `UPPER_BOUND_CALC.md` bleibt
  gültig. Die Bar ist nur nicht mehr die Größe, an der die Entscheidung hängt.
* **Nicht, dass ein Konto gekauft werden soll.** Das ist eine Kaufentscheidung und damit
  OWNER-Fenster; die stehende Doktrin verlangt bis dahin eine Bar, die weiterhin nicht erreicht ist.
* **Nicht, dass n = 50 Fensterstarts viel sind.** Es sind 50 überlappungsfreie Startpunkte aus
  8,2 Jahren derselben 21 Sleeves. Die Populationsgrenze aus rev6 gilt unverändert.
* **Nicht, dass Slippage, Feed-Differenz und reale Ausführung enthalten wären.** Sie sind es nicht —
  das ist genau das, was `LIVETEST_OPTION.md` als einzige offene Messgröße benennt.

## 6 · Was daraus für die Zielgröße folgt

Die Bar „Bootstrap-Untergrenze P(P1) ≥ 0,80" misst **einen** Versuch und ignoriert, was danach
passiert. Die Rechnung oben zeigt, dass die relevante Größe hinter der Finanzierung liegt und in die
**entgegengesetzte** Richtung zeigt: höheres Sizing hebt die Bestehensquote und senkt den Ertrag.

**Vorschlag für die Ersatzgröße, entscheidungsreif, nicht gesetzt:**

> **Erwartete Auszahlung je Versuch, unter der pessimistischen Intraday-Schranke, ≥ dem Zehnfachen
> der Challenge-Gebühr.**

Bei 0,50× ist dieses Kriterium mit 15.555 $ Break-even um mehr als eine Größenordnung erfüllt,
sofern die Gebühr im vierstelligen Bereich liegt — was OWNER in einer Minute prüfen kann und ich
nicht behaupte.

**Damit ist die Rechnung dieser Datenbasis abgeschlossen.** Was an ihr noch offen ist, ist nicht
rechenbar, sondern nur messbar: reale Ausführung.
