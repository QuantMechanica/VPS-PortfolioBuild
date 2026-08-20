# SETFILE_EMPTY_PARAMS_CLASS — die Mauer, die nur Gewinner stoppt

**Stand:** 2026-08-20 00:55 UTC · Anlass: Q08-INVALID `baseline_setfile_defect:empty_strategy_params`
für QM5_10771 XAUUSD und QM5_11132 NDX (00:28/00:29 UTC)

---

## 0 · Der Befund

> **1.557 von 3.001 EAs (52 %) tragen in keinem Backtest-Setfile einen einzigen
> `strategy_*`-Schlüssel — 1.508 davon mit `card_defaults_source=not_found`: gebaut ohne
> Karte, alle Strategie-Parameter einkompiliert.** Q08-Untergate 8.5 (Nachbarschaft) kann
> ohne exponierte Parameter keine Störung rechnen und verweigert fail-closed → INVALID.
>
> Kein Degradationsschaden: die Setfiles sind seit ihrem Erstellungs-Commit so
> (geprüft an QM5_10771, `git log --follow`). Es ist die Bauweise der tv-/Port-Ära
> (ID-Band 1xxxx: 1.247 der 1.557; moderne Bänder 2–4xxxx: nur 24).

## 1 · Warum das bisher fast unsichtbar war

Q02–Q07 brauchen keine Setfile-Parameter — die Klasse läuft dort normal durch und
liefert gültige Verdikte. Die Mauer steht erst bei Q08. Historisch nur **2** INVALIDs
dieser Klasse, weil die Alt-Kohorte selten so weit überlebt. **Genau das ist die
Ironie: die Mauer stoppt ausschließlich die Überlebenden** — die beiden heutigen
INVALIDs sind Q07-Passer mit dokumentierter Ökonomie.

## 2 · Exposition

| | |
|---|---:|
| betroffene EAs | 1.557 |
| pending Zeilen dieser EAs | **1.434 (63 % der Queue)** |
| davon Q04 / Q02 | 989 / 394 |
| nahe der Mauer (Q05–Q09 pending) | **28** |
| Q08-INVALID bisher | 2 (QM5_10771, QM5_11132) |

Die 1.434 Zeilen sind **nicht wertlos** — Q02–Q07-Verdikte messen die Strategie
regulär. Nur der Q08-Durchgang ist as built unmöglich.

## 3 · Optionen (Vorlage — nichts ausgeführt)

- **(a) Survivor-Port bei Aufprall (empfohlen):** Jeder EA dieser Klasse, der Q07
  besteht bzw. Q08-INVALID-empty-params erhält, wird über die reguläre Build-Lane
  als Parameter-exponierter Sibling neu gebaut (Survivor-Port-Reinheit gilt) und
  durchläuft die Pipeline neu. Kosten fallen nur für nachgewiesene Überlebende an.
  Kandidaten heute: QM5_10771 (XAUUSD, Q07-Passer), QM5_11132 (NDX, Q07-Passer).
- **(b) Proaktive Ports der 28 Frontier-Zeilen:** vermeidet verbrannte
  Q05–Q07-Slots, baut aber ~2 Dutzend EAs auf Verdacht.
- **(c) Nichts tun, INVALIDs zählen:** kostenneutral, verliert aber je Überlebendem
  die gesamte Gate-Historie ein zweites Mal (Port muss ohnehin neu laufen).

Ampel: **(a) ist reguläre Fabrikarbeit** (Build-Lane, Survivor-Port-Prozess) — als
Auffangregel-fähig eingestuft (reversibel: Build-Task stornierbar, keine Gate-Logik
berührt). (b)/(c) sind OWNER-Präferenzfragen.

## 3a · KORREKTUR 05:30 UTC — die Mauer ist schmaler als der Zensus

**QM5_10114 (parameterlos, `not_found`) hat Q08-8.5 BESTANDEN** (Verdikt FAIL_SOFT via
PBO/LOW_SAMPLE, 8.5 = PASS; Polster 80×, MC-DD 3,3 %, 37 Trades). Das Prädikat „keine
`strategy_*`-Schlüssel ⇒ 8.5-INVALID" ist damit **widerlegt**. Der wahre Auslöser bei
10771/11132 ist ein Defekt in der **Nachbarschafts-Evidenz-Lineage** (vermutlich
Q03-Plateau-Herkunft), nicht die leere Parameterliste allein — 8.5 kann Nachbarschaft
offenbar aus der Plateau-Lineage beziehen. Die 1.557-EA-Exposition aus §2 ist eine
**Obergrenze**, die tatsächliche Mauer-Population ist unbekannt und vermutlich deutlich
kleiner. Die Survivor-Port-Empfehlung (a) bleibt für die konkreten INVALID-Fälle richtig,
ihre Dringlichkeit sinkt; vor jedem proaktiven Port (b) steht jetzt zwingend die
Lineage-Analyse: **was unterscheidet 10771/11132 von 10114?**

## 4 · Nebenbefund fürs Protokoll

Der Zeilenzahl-Zensus der ersten Iteration (≤20 Zeilen ⇒ defekt) war das falsche
Prädikat — auch gesunde moderne Setfiles sind 13-zeilig plus `strategy_*`-Block.
Das korrekte Prädikat ist „kein `strategy_*`-Schlüssel". Erst die Stichprobe am
Q08-PASS-Piloten (QM5_11294, 13 Zeilen, PASS) hat das aufgedeckt.
